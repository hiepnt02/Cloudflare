//
//  ARFrame++.swift
//  Quick3D
//
//  Created by HaNST on 12/3/26.
//

import ARKit
import Foundation
import Network

extension ARFrame {
    var time: Date {
        let timeIntervalFromFrame: TimeInterval = self.timestamp - CACurrentMediaTime()
        let trueTime = AccurateClock.shared.nowUTC()
        let timestamp = trueTime.addingTimeInterval(timeIntervalFromFrame)
        return timestamp
    }    
}

enum NTPError: Error {
    case invalidResponse
    case timedOut
    case connectionFailed
}

struct NTPMeasurement {
    let server: String
    let ntpDate: Date
    let localDate: Date
    let uptime: TimeInterval
    let offset: TimeInterval
    let rtt: TimeInterval
    let rawData: Data
    let rawTime: [Date]
    let rawUptime: [TimeInterval]
}

enum NTPTimeType{
    case T1
    case T2
    case T3
    case T4
}

final class NTPClient {
    private let timeout: TimeInterval = 2.0
    private let ntpPort: UInt16 = 123
    private let ntpEpochOffset: TimeInterval = 2_208_988_800 // 1900 -> 1970

    func query(server: String) async throws -> NTPMeasurement {
        try await withCheckedThrowingContinuation { continuation in
            let host = NWEndpoint.Host(server)
            guard let port = NWEndpoint.Port(rawValue: ntpPort) else {
                continuation.resume(throwing: NTPError.connectionFailed)
                return
            }

            let connection = NWConnection(host: host, port: port, using: .udp)
            let queue = DispatchQueue(label: "ntp.\(server)")

            var sendUptime = self.SystemUptime()
            var sendWallClock = Date()

            var resumed = false
            func finish(_ result: Result<NTPMeasurement, Error>) {
                guard !resumed else { return }
                resumed = true
                connection.cancel()
                continuation.resume(with: result)
            }
            
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    var packet = Data(repeating: 0, count: 48)
                    packet[0] = 0x1B // LI=0, VN=3, Mode=3(client)
                    sendUptime = self.SystemUptime()
                    sendWallClock = Date()

                    connection.send(content: packet, completion: .contentProcessed { error in
                        if let error {
                            finish(.failure(error))
                        }
                    })

                    queue.asyncAfter(deadline: .now() + self.timeout) {
                        finish(.failure(NTPError.timedOut))
                    }

                case .failed(let error):
                    finish(.failure(error))

                default:
                    break
                }
            }

            connection.receiveMessage { data, _, _, error in
                let receiveUptime = self.SystemUptime()
                let rtt = receiveUptime - sendUptime
                
                if let error {
                    finish(.failure(error))
                    return
                }

                guard let data, data.count >= 48 else {
                    finish(.failure(NTPError.invalidResponse))
                    return
                }

                do {
                    // 受信時点のローカル壁時計と比較
                    
                    let t1 = sendWallClock
                    let t2 = try self.parseTransmitTimestamp(from: data, type: .T2)
                    let t3 = try self.parseTransmitTimestamp(from: data, type: .T3)
                    let t4 = sendWallClock.addingTimeInterval(rtt)
                    
                    let ntpDate = t3
                    
                    let localDate = t1.addingTimeInterval(rtt / 2.0)
                    
                    let offset = ntpDate.timeIntervalSince(localDate)
                    
                    let rawUptime = [sendUptime, receiveUptime]
                    let uptime = sendUptime + rtt / 2.0

                    let rawTime = [t1,t2,t3,t4]
                                        
                    let measurement = NTPMeasurement(
                        server: server,
                        ntpDate: ntpDate,
                        localDate: localDate,
                        uptime: uptime,
                        offset: offset,
                        rtt: rtt,
                        rawData: data,
                        rawTime: rawTime,
                        rawUptime: rawUptime
                    )
                    finish(.success(measurement))
                } catch {
                    finish(.failure(error))
                }
            }

            connection.start(queue: queue)
        }
    }

    private func parseTransmitTimestamp(from data: Data, type: NTPTimeType = .T3) throws -> Date {
        guard data.count >= 48 else { throw NTPError.invalidResponse }
        let start: Int
        switch type {
            case .T1: start = 24
            case .T2: start = 32
            case .T3: start = 40
            default : throw NTPError.invalidResponse
        }
        
        let seconds = readUInt32BE(data, start: start)
        let fraction = readUInt32BE(data, start: start + 4)

        let unixSeconds = TimeInterval(seconds) - ntpEpochOffset
        let fractionalSeconds = TimeInterval(fraction) / 4_294_967_296.0

        return Date(timeIntervalSince1970: unixSeconds + fractionalSeconds)
    }

    private func readUInt32BE(_ data: Data, start: Int) -> UInt32 {
        let b0 = UInt32(data[start]) << 24
        let b1 = UInt32(data[start + 1]) << 16
        let b2 = UInt32(data[start + 2]) << 8
        let b3 = UInt32(data[start + 3])
        return b0 | b1 | b2 | b3
    }
    
    func SystemUptime() -> TimeInterval {
        return ProcessInfo.processInfo.systemUptime
    }
}

final class AccurateClock {
    private var initialUTC: Date?
    private var initialUptime: TimeInterval = 0
    private var smoothingDelta: TimeInterval = 0
    private var task: Task<Void, Never>?
    private var logText: String = ""
    
    private var ntpMeasurements: [NTPMeasurement] = []
    private let maxSampleCount: Int = 100
    private let initialAttempt: Int = 10

    private let requiredRTT = 2.0
    private let requiredSTD = 0.025

    private let client = NTPClient()
    
    public static let shared = AccurateClock()
    
    private init(){
        initialUTC = Date()
        initialUptime = client.SystemUptime()
    }
    
    func start() {
        guard task == nil else { return }
        // init attempt
        self.logText = ""
        task = Task {
            for _ in 0..<self.initialAttempt {
                await self.synchronize()
            }
            while self.ntpMeasurements.count < self.maxSampleCount && !Task.isCancelled  {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await self.synchronize()
            }
            end()
        }
    }
    
    func end() {
        if !logText.isEmpty {
            print(self.logText)
        }
    }
    
    func stop() {
        task?.cancel()
        task = nil
    }
    
    func reset(){
        smoothingDelta = 0
        initialUTC = Date()
        initialUptime = client.SystemUptime()
        ntpMeasurements = []
        logText = ""
        stop()
        self.start()
    }
    
    private func synchronize() async {
       
        let servers = [
            "time.apple.com",
//            "time.cloudflare.com",
//            "time.google.com",
//            "ntp.nict.jp",
//            "ntp.jst.mfeed.ad.jp",
        ]

        var results: [NTPMeasurement] = []

        await withTaskGroup(of: NTPMeasurement?.self) { group in
            for server in servers {
                group.addTask {
                    do {
                        return try await self.client.query(server: server)
                    } catch {
                        return nil
                    }
                }
            }

            for await result in group {
                if let result {
                    results.append(result)
                }
            }
        }

        guard let best = results.min(by: { $0.rtt < $1.rtt }) else {
            return
        }
        
        if best.rtt > 0.0  &&  best.rtt < requiredRTT
        {
            if self.ntpMeasurements.count == 0 {
                self.initialUTC = best.ntpDate
                self.initialUptime = best.uptime
                self.smoothingDelta = 0
            }
            
            self.ntpMeasurements.append(best)
            self.calculate()
        } else {
        }
        
    }
    private func calculate() {
        
        if self.ntpMeasurements.count < 2 {
            return
        }
        let N = self.ntpMeasurements.count
        var sumweight: Double = 0.0
        var sumdelta: Double = 0.0
        let ntpFirst = self.ntpMeasurements.first!
        let initialTheta = ntpFirst.ntpDate.timeIntervalSince1970 - ntpFirst.uptime
        
        // calculate theta
        for i in 0..<N {
            let ntp = self.ntpMeasurements[i]
            
            let weight = 1.0 / ntp.rtt / ntp.rtt
           
            let theta_i = ntp.ntpDate.timeIntervalSince1970 - ntp.uptime
            
            let delta_i = theta_i - initialTheta
            
            sumdelta += weight * delta_i
            sumweight += weight
        }
        let delta = sumdelta / sumweight
        
        self.smoothingDelta = delta
        
//        validateError()
    }
    
    
    
    private func validateError(){
        let N = self.ntpMeasurements.count
        let delta = self.smoothingDelta
        let ntpFirst = self.ntpMeasurements.first!
        let initialTheta = ntpFirst.ntpDate.timeIntervalSince1970 - ntpFirst.uptime

        
        // calculate error
        var variance = 0.0
        var maxDelta: Double = 0.0
        var minDelta: Double = 0.0
        var sumweight: Double = 0.0
        for i in 0..<N {
            let ntp = self.ntpMeasurements[i]
            
            let weight = 1.0 / ntp.rtt / ntp.rtt
            sumweight += weight
            
            let theta_i = ntp.ntpDate.timeIntervalSince1970 - ntp.uptime
             
            let delta_i = theta_i - initialTheta
            
            if delta_i > maxDelta {
                maxDelta = delta_i
            }
            if delta_i < minDelta {
                minDelta = delta_i
            }
            variance += pow(delta_i - delta, 2.0) * weight
        }
        variance /= sumweight
        variance /= (Double(N) - 1.0)
        let standardError = sqrt(variance)
        
        let currentTime = self.nowUTC()
        let offset = currentTime.timeIntervalSince(Date())
        let ntpLast = self.ntpMeasurements.last!
        let lastRTT = ntpLast.rtt
        let error = ntpLast.ntpDate.timeIntervalSince1970 - ntpLast.uptime - initialTheta - delta
        let isValid = standardError < self.requiredSTD ? "OK" : "NG"
        
        let log = "N=\(N), valid=\(isValid), offset=\(offset), [min,max]=[\(minDelta - delta),\(maxDelta - delta)], SE=\(standardError), rrt=\(lastRTT), error=\(error)"
        logText.append(log)
        logText.append("\n")
        
        print(log)
    }
    
    func nowUTC() -> Date {
        guard let initialUTC else { return Date() }
        let elapsed = client.SystemUptime() - initialUptime + smoothingDelta
        return initialUTC.addingTimeInterval(elapsed)
    }

    func currentLocalClockSkew() -> TimeInterval {
        nowUTC().timeIntervalSince(Date())
    }
}
