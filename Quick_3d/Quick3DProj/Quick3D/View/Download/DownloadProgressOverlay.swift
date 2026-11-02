//
//  DownloadProgressOverlay.swift
//  Quick3D
//

import SwiftUI

struct DownloadOverlayRow: Identifiable, Equatable {
    let id: String
    let name: String
    let fraction: Double
    let percentText: String
    let sizeText: String?
    let isWaiting: Bool
    let failure: DownloadFailureReason?
    var isCompleted = false

    static func rows(from states: [String: DownloadPhase], name: (String) -> String?) -> [DownloadOverlayRow] {
        states.compactMap { projectId, phase -> DownloadOverlayRow? in
            let displayName = name(projectId) ?? projectId
            switch phase {
            case .completed:
                return DownloadOverlayRow(
                    id: projectId, name: displayName, fraction: 1, percentText: "100%", sizeText: nil, isWaiting: false,
                    failure: nil, isCompleted: true
                )
            case .waiting:
                return DownloadOverlayRow(
                    id: projectId, name: displayName, fraction: 0, percentText: "0%", sizeText: nil, isWaiting: true,
                    failure: nil
                )
            case .downloading(let received, let total), .paused(let received, let total):
                return DownloadOverlayRow(
                    id: projectId,
                    name: displayName,
                    fraction: phase.fraction,
                    percentText: "\(Int(phase.fraction * 100))%",
                    sizeText: total > 0 ? "\(megabytes(received)) / \(megabytes(total))" : megabytes(received),
                    isWaiting: false,
                    failure: nil
                )
            case .failed(let reason):
                return DownloadOverlayRow(
                    id: projectId, name: displayName, fraction: 0, percentText: "", sizeText: nil, isWaiting: false,
                    failure: reason
                )
            }
        }
        .sorted {
            let order = $0.name.localizedStandardCompare($1.name)
            return order == .orderedSame ? $0.id < $1.id : order == .orderedAscending
        }
    }

    static func failureKey(_ reason: DownloadFailureReason) -> String {
        switch reason {
        case .network: return "GSX_DOWNLOAD_ROW_NETWORK_LOST"
        case .storageFull: return "GSX_DOWNLOAD_STORAGE_FULL"
        case .interrupted, .unauthorized, .server, .invalidResponse, .unknown: return "GSX_DOWNLOAD_FAILED"
        }
    }

    static func isOverlayVisible(_ rows: [DownloadOverlayRow]) -> Bool {
        !rows.isEmpty
    }

    static func isDownloadInProgress(_ rows: [DownloadOverlayRow]) -> Bool {
        rows.contains { $0.failure == nil && !$0.isCompleted }
    }

    static func overallPercentText(_ rows: [DownloadOverlayRow]) -> String {
        let counted = rows.filter { $0.failure == nil }
        guard !counted.isEmpty else { return "" }
        let mean = counted.map(\.fraction).reduce(0, +) / Double(counted.count)
        return "\(Int(mean * 100))%"
    }

    static func freeSpaceText(_ bytes: Int64?) -> String? {
        bytes.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) }
    }

    private static func megabytes(_ bytes: Int64) -> String {
        String(format: "%.1f MB", Double(bytes) / 1_048_576)
    }
}

struct DownloadProgressOverlay: View {

    @EnvironmentObject var downloadQueue: DownloadQueueManager
    @EnvironmentObject var userManager: UserManager

    @State private var isMinimized = false

    var body: some View {
        let rows = DownloadOverlayRow.rows(from: downloadQueue.states, name: downloadQueue.displayName(for:))
        let isVisible = DownloadOverlayRow.isOverlayVisible(rows)
        ZStack {
            if isVisible {
                if isMinimized {
                    minimizedBadge(rows)
                } else {
                    expandedPanel(rows)
                }
            }
        }
        .onChange(of: isVisible) { visible in
            if !visible { isMinimized = false }
        }
    }

    private func setMinimized(_ minimized: Bool) {
        withAnimation(.easeInOut(duration: 0.2)) { isMinimized = minimized }
    }

    private func minimizedBadge(_ rows: [DownloadOverlayRow]) -> some View {
        let hasFailure = rows.contains { $0.failure != nil }
        let isDownloading = DownloadOverlayRow.isDownloadInProgress(rows)
        return Button {
            setMinimized(false)
        } label: {
            HStack(spacing: 6) {
                if isDownloading {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.accentColor)
                    Text(DownloadOverlayRow.overallPercentText(rows))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                } else {
                    Image(systemName: hasFailure ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundColor(hasFailure ? .red : .green)
                }
                if isDownloading && hasFailure {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                }
            }
            .font(.system(size: 20))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(UIColor.systemBackground).opacity(0.95))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .padding(.leading, 16)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.scale(scale: 0.5, anchor: .bottomLeading).combined(with: .opacity))
    }

    private func expandedPanel(_ rows: [DownloadOverlayRow]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Spacer()
                Button {
                    setMinimized(true)
                } label: {
                    Image(systemName: "chevron.down.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            ForEach(rows) { row in
                rowView(row)
            }
            Divider()
            let isDownloading = DownloadOverlayRow.isDownloadInProgress(rows)
            if isDownloading {
                Text(localized("GSX_DOWNLOAD_KEEP_APP_OPEN"))
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                if let freeSpace = DownloadOverlayRow.freeSpaceText(DownloadStorage().freeBytes) {
                    Text(String(format: localized("GSX_DOWNLOAD_FREE_SPACE"), freeSpace))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if !isDownloading {
                    Button(localized("CLOSE")) {
                        downloadQueue.dismissFinished()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(12)
        .background(Color(UIColor.systemBackground).opacity(0.95))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .frame(maxWidth: 600)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func rowView(_ row: DownloadOverlayRow) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(row.name)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Spacer()
                    if row.isCompleted {
                        Label(localized("GSX_DOWNLOAD_COMPLETED"), systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.green)
                    } else if row.failure == nil {
                        Text(row.isWaiting ? localized("GSX_DOWNLOAD_WAITING") : row.percentText)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                if let failure = row.failure {
                    Text(localized(DownloadOverlayRow.failureKey(failure)))
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ProgressView(value: row.fraction)
                        .tint(row.isCompleted ? .green : nil)
                }
                if let sizeText = row.sizeText {
                    Text(sizeText)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            if row.failure != nil {
                Button(localized("GSX_DOWNLOAD_RETRY")) {
                    downloadQueue.retry(projectId: row.id)
                }
                .font(.system(size: 14, weight: .semibold))
                .buttonStyle(.borderless)
            }
            Button {
                downloadQueue.requestCancel(projectId: row.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func localized(_ key: String) -> String {
        key.localized(userManager.userLanguage)
    }
}
