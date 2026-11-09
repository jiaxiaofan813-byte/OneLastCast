import AppKit
let base = "<project-root>/assets/fish20/"
let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath:base+"manifest.json"))) as! [String:Any]
let chinese=["蓝鳃太阳鱼","南瓜籽太阳鱼","黑莓鲈","黄鲈","大口黑鲈","大眼梭鲈","白斑狗鱼","小口黑鲈","斑点黑鲈","白鲈","条纹鲈","岩钝鲈","白莓鲈","绿太阳鱼","红耳太阳鱼","长耳太阳鱼","斑点叉尾鮰","蓝鲶","溪红点鲑","虹鳟"]
let entries = manifest["species"] as! [[String:Any]]
for small in [false,true] {
 let file=small ? "contact-sheet-game-size.png" : "contact-sheet.png"
 let w=small ? 1100 : 1400, h=small ? 780 : 1700
 let cw=small ? 275 : 350, ch=small ? 156 : 340
 let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:w,pixelsHigh:h,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
 let ctx=NSGraphicsContext(bitmapImageRep:bitmap)!
 NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current=ctx
 let image=NSImage(contentsOfFile:base+file)!
 image.draw(in:NSRect(x:0,y:0,width:w,height:h))
 let attrs:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:17,weight:.medium),.foregroundColor:NSColor(red:0.14,green:0.30,blue:0.31,alpha:1)]
 for (i,e) in entries.enumerated() {
  let text=String(format:"%02d. %@",i+1,e["name"] as! String) as NSString
  let size=text.size(withAttributes:attrs)
  text.draw(at:NSPoint(x:Double(i%4*cw)+Double(cw)/2-size.width/2,y:Double(h-(i/4+1)*ch+42)),withAttributes:attrs)
  let zh=chinese[i] as NSString
  let zs=zh.size(withAttributes:attrs)
  zh.draw(at:NSPoint(x:Double(i%4*cw)+Double(cw)/2-zs.width/2,y:Double(h-(i/4+1)*ch+18)),withAttributes:attrs)
 }
 NSGraphicsContext.restoreGraphicsState()
 try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:base+file))
 print("Labeled \(file)")
}
