import Foundation
@main struct DiscoveryPlanTest {
    static func main() {
        let hotspot = DiscoveryPlan.hosts(address:"172.20.10.1",mask:"255.255.255.240")
        precondition(hotspot.count == 13)
        precondition(hotspot.first == "172.20.10.2" && hotspot.last == "172.20.10.14")
        precondition(!hotspot.contains("172.20.10.1"))
        let lan = DiscoveryPlan.hosts(address:"192.168.219.7",mask:"255.255.255.0")
        precondition(lan.count == 253 && !lan.contains("192.168.219.7"))
        precondition(DiscoveryPlan.hosts(address:"10.2.3.4",mask:"255.0.0.0").count == 253)
        precondition(DiscoveryPlan.hosts(address:"8.8.8.8",mask:"255.255.255.0").isEmpty)
        precondition(DiscoveryPlan.hosts(address:"172.20.10.1",mask:"255.255.0.255").isEmpty)
        precondition(DiscoveryPlan.hosts(address:"172.20.10.1",mask:"255.255.255.255").isEmpty)
        let duplicate = DiscoveryPlan.candidates(interfaces:[("172.20.10.1","255.255.255.240")])
        precondition(duplicate == hotspot)
        precondition(DiscoveryPlan.candidates(interfaces:[]) == hotspot)
        precondition(DiscoveryPlan.isGlasses(Data("{\"service\":\"Rokid OSM Voice\",\"version\":\"0.3.0\"}".utf8)))
        precondition(!DiscoveryPlan.isGlasses(Data("{\"service\":\"Other\",\"version\":\"0.3.0\"}".utf8)))
        precondition(!DiscoveryPlan.isGlasses(Data("not json".utf8)))
        print("PASS 13 discovery address and identity checks")
    }
}
