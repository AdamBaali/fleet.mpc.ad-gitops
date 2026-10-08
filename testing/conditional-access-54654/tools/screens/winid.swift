import Foundation
import CoreGraphics
// usage: winid <owner-name-substring> [title-substring]  -> prints the CGWindowID of the front-most matching normal window
let a = CommandLine.arguments
let owner = a.count > 1 ? a[1] : ""
let title = a.count > 2 ? a[2] : ""
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as! [[String: Any]]
for w in list {
  guard (w[kCGWindowLayer as String] as? Int) == 0,
        let o = w[kCGWindowOwnerName as String] as? String, o.contains(owner),
        let id = w[kCGWindowNumber as String] as? Int else { continue }
  let t = (w[kCGWindowName as String] as? String) ?? ""
  if !title.isEmpty && !t.contains(title) { continue }
  let b = w[kCGWindowBounds as String] as? [String: Any]
  if let h = b?["Height"] as? Double, h < 100 { continue }
  print(id); exit(0)
}
exit(1)
