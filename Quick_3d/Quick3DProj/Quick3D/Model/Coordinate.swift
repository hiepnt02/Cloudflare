//
//  Coordinate.swift
//  Quick3D
//
//  Created by ryoma.terai on 2024/10/08.
//

import Foundation

public struct CoordinateSystem {
    let label: String
    let value: Int
}

public struct VerticalDatum {
    let label: String
    let value: Int
}

let cood: [CoordinateSystem] = [
    CoordinateSystem(label: "EPSG:4326 / WGS84 / World Geodetic System 1984, used in GPS", value: 4326),
    CoordinateSystem(label: "EPSG:6669 / JGD2011 / Japan Plane Rectangular CS I", value: 6669),
    CoordinateSystem(label: "EPSG:6670 / JGD2011 / Japan Plane Rectangular CS II", value: 6670),
    CoordinateSystem(label: "EPSG:6671 / JGD2011 / Japan Plane Rectangular CS III", value: 6671),
    CoordinateSystem(label: "EPSG:6672 / JGD2011 / Japan Plane Rectangular CS IV", value: 6672),
    CoordinateSystem(label: "EPSG:6673 / JGD2011 / Japan Plane Rectangular CS V", value: 6673),
    CoordinateSystem(label: "EPSG:6674 / JGD2011 / Japan Plane Rectangular CS VI", value: 6674),
    CoordinateSystem(label: "EPSG:6675 / JGD2011 / Japan Plane Rectangular CS VII", value: 6675),
    CoordinateSystem(label: "EPSG:6676 / JGD2011 / Japan Plane Rectangular CS VIII", value: 6676),
    CoordinateSystem(label: "EPSG:6677 / JGD2011 / Japan Plane Rectangular CS IX", value: 6677),
    CoordinateSystem(label: "EPSG:6678 / JGD2011 / Japan Plane Rectangular CS X", value: 6678),
    CoordinateSystem(label: "EPSG:6679 / JGD2011 / Japan Plane Rectangular CS XI", value: 6679),
    CoordinateSystem(label: "EPSG:6680 / JGD2011 / Japan Plane Rectangular CS XII", value: 6680),
    CoordinateSystem(label: "EPSG:6681 / JGD2011 / Japan Plane Rectangular CS XIII", value: 6681),
    CoordinateSystem(label: "EPSG:6682 / JGD2011 / Japan Plane Rectangular CS XIV", value: 6682),
    CoordinateSystem(label: "EPSG:6683 / JGD2011 / Japan Plane Rectangular CS XV", value: 6683),
    CoordinateSystem(label: "EPSG:6684 / JGD2011 / Japan Plane Rectangular CS XVI", value: 6684),
    CoordinateSystem(label: "EPSG:6685 / JGD2011 / Japan Plane Rectangular CS XVII", value: 6685),
    CoordinateSystem(label: "EPSG:6686 / JGD2011 / Japan Plane Rectangular CS XVIII", value: 6686),
    CoordinateSystem(label: "EPSG:6687 / JGD2011 / Japan Plane Rectangular CS XIX", value: 6687),
    CoordinateSystem(label: "EPSG:6688 / JGD2011 / UTM zone 51N", value: 6688),
    CoordinateSystem(label: "EPSG:6689 / JGD2011 / UTM zone 52N", value: 6689),
    CoordinateSystem(label: "EPSG:6690 / JGD2011 / UTM zone 53N", value: 6690),
    CoordinateSystem(label: "EPSG:6691 / JGD2011 / UTM zone 54N", value: 6691),
    CoordinateSystem(label: "EPSG:6692 / JGD2011 / UTM zone 55N", value: 6692),
    CoordinateSystem(label: "EPSG:2443 / JGD2000 / Japan Plane Rectangular CS I", value: 2443),
    CoordinateSystem(label: "EPSG:2444 / JGD2000 / Japan Plane Rectangular CS II", value: 2444),
    CoordinateSystem(label: "EPSG:2445 / JGD2000 / Japan Plane Rectangular CS III", value: 2445),
    CoordinateSystem(label: "EPSG:2446 / JGD2000 / Japan Plane Rectangular CS IV", value: 2446),
    CoordinateSystem(label: "EPSG:2447 / JGD2000 / Japan Plane Rectangular CS V", value: 2447),
    CoordinateSystem(label: "EPSG:2448 / JGD2000 / Japan Plane Rectangular CS VI", value: 2448),
    CoordinateSystem(label: "EPSG:2449 / JGD2000 / Japan Plane Rectangular CS VII", value: 2449),
    CoordinateSystem(label: "EPSG:2450 / JGD2000 / Japan Plane Rectangular CS VIII", value: 2450),
    CoordinateSystem(label: "EPSG:2451 / JGD2000 / Japan Plane Rectangular CS IX", value: 2451),
    CoordinateSystem(label: "EPSG:2452 / JGD2000 / Japan Plane Rectangular CS X", value: 2452),
    CoordinateSystem(label: "EPSG:2453 / JGD2000 / Japan Plane Rectangular CS XI", value: 2453),
    CoordinateSystem(label: "EPSG:2454 / JGD2000 / Japan Plane Rectangular CS XII", value: 2454),
    CoordinateSystem(label: "EPSG:2455 / JGD2000 / Japan Plane Rectangular CS XIII", value: 2455),
    CoordinateSystem(label: "EPSG:2456 / JGD2000 / Japan Plane Rectangular CS XIV", value: 2456),
    CoordinateSystem(label: "EPSG:2457 / JGD2000 / Japan Plane Rectangular CS XV", value: 2457),
    CoordinateSystem(label: "EPSG:2458 / JGD2000 / Japan Plane Rectangular CS XVI", value: 2458),
    CoordinateSystem(label: "EPSG:2459 / JGD2000 / Japan Plane Rectangular CS XVII", value: 2459),
    CoordinateSystem(label: "EPSG:2460 / JGD2000 / Japan Plane Rectangular CS XVIII", value: 2460),
    CoordinateSystem(label: "EPSG:2461 / JGD2000 / Japan Plane Rectangular CS XIX", value: 2461),
    CoordinateSystem(label: "EPSG:3097 / JGD2000 / UTM zone 51N", value: 3097),
    CoordinateSystem(label: "EPSG:3098 / JGD2000 / UTM zone 52N", value: 3098),
    CoordinateSystem(label: "EPSG:3099 / JGD2000 / UTM zone 53N", value: 3099),
    CoordinateSystem(label: "EPSG:3100 / JGD2000 / UTM zone 54N", value: 3100),
    CoordinateSystem(label: "EPSG:3101 / JGD2000 / UTM zone 55N", value: 3101),
    CoordinateSystem(label: "EPSG:32651 / WGS84 / UTM zone 51N", value: 32651),
    CoordinateSystem(label: "EPSG:32652 / WGS84 / UTM zone 52N", value: 32652),
    CoordinateSystem(label: "EPSG:32653 / WGS84 / UTM zone 53N", value: 32653),
    CoordinateSystem(label: "EPSG:32654 / WGS84 / UTM zone 54N", value: 32654),
    CoordinateSystem(label: "EPSG:32655 / WGS84 / UTM zone 55N", value: 32655)
]

let vertical: [VerticalDatum] = [
    VerticalDatum(label: "EPSG:5773 / EGM96 height", value: 5773),
    VerticalDatum(label: "EPSG:6695 / JGD2011 height (gsigeo2011_ver2_1 geoid)", value: 6695),
    VerticalDatum(label: "EPSG:6694 / JGD2000 height (gsigeo2011_ver2_1 geoid)", value: 6694)
]


public func getHorizontalLabel(from value: Int?) -> String{
    if(value != nil){
        return cood.first { $0.value == value }?.label ?? ""
    }
    else{
        return ""
    }
    
}

public func getVerticalLabel(from value: Int?) -> String{
    if(value != nil){
        return vertical.first { $0.value == value }?.label ?? ""
    }
    else{
        return ""
    }
    
}

public func extractEPSGValue(from text: String?) -> Int? {
    if(text != nil){
        let components = text!.components(separatedBy: ":")
        if let numberString = components.last, let number = Int(numberString) {
            return number
        }
    }
    else{
        return nil
    }
    return nil
}
