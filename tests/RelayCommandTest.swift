import Foundation
@main struct RelayCommandTest {
 static func main() throws {
  let data = try RelayCommand.destination(name:"전북대학교",latitude:35.846,longitude:127.13,mode:.bicycle)
  let json = try JSONSerialization.jsonObject(with:data) as! [String:Any]
  precondition(json["name"] as? String == "전북대학교")
  precondition(json["mode"] as? String == "bicycle")
  precondition(json["lat"] as? Double == 35.846 && json["lon"] as? Double == 127.13)
  let walking = try JSONSerialization.jsonObject(with:RelayCommand.destination(name:"서울시청",latitude:37.56,longitude:126.97,mode:.pedestrian)) as! [String:Any]
  precondition(walking["mode"] as? String == "pedestrian")
  for coordinate in [Double.nan,Double.infinity,91.0] {
   do { _ = try RelayCommand.destination(name:"x",latitude:coordinate,longitude:127,mode:.bicycle); preconditionFailure("invalid latitude accepted") } catch { }
  }
  do { _ = try RelayCommand.destination(name:" ",latitude:37,longitude:127,mode:.bicycle); preconditionFailure() } catch { }
  for action in ["zoomIn","zoomOut","overview"] {
   let command = try JSONSerialization.jsonObject(with:RelayCommand.map(action)) as! [String:Any]
   precondition(command["action"] as? String == action)
  }
  do { _ = try RelayCommand.map("javascript()"); preconditionFailure() } catch { }
  print("PASS 12 destination and map command checks")
 }
}
