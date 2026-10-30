import SwiftUI

struct PotaBody: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + rect.width*x, y: rect.minY + rect.height*y) }
        p.move(to: point(0.52, 0.05))
        p.addCurve(to: point(0.9, 0.62), control1: point(0.57, 0.25), control2: point(0.9, 0.32))
        p.addCurve(to: point(0.5, 0.94), control1: point(0.96, 0.88), control2: point(0.76, 0.96))
        p.addCurve(to: point(0.1, 0.62), control1: point(0.22, 0.96), control2: point(0.04, 0.84))
        p.addCurve(to: point(0.52, 0.05), control1: point(0.1, 0.4), control2: point(0.43, 0.2))
        p.closeSubpath()
        return p
    }
}

struct PotaView: View {
    var resting = false
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                Ellipse().fill(Color.black.opacity(0.06)).frame(width: w*0.66, height: h*0.065).offset(y: h*0.43)
                Ellipse().fill(Color(red: 0.23, green: 0.55, blue: 0.48)).frame(width:w*0.22, height:h*0.09).rotationEffect(.degrees(-14)).offset(x:-w*0.2,y:h*0.37)
                Ellipse().fill(Color(red: 0.23, green: 0.55, blue: 0.48)).frame(width:w*0.22, height:h*0.09).rotationEffect(.degrees(14)).offset(x:w*0.2,y:h*0.37)
                PotaBody().fill(LinearGradient(colors:[Color(red:0.72,green:0.91,blue:0.78), Color(red:0.38,green:0.76,blue:0.67)], startPoint:.topLeading,endPoint:.bottomTrailing))
                PotaBody().stroke(Color(red:0.19,green:0.49,blue:0.41).opacity(0.15),lineWidth:1.5)
                Ellipse().fill(.white.opacity(0.5)).frame(width:w*0.09,height:h*0.15).rotationEffect(.degrees(30)).offset(x:-w*0.19,y:-h*0.1)
                HStack(spacing:w*0.2) {
                    eye.frame(width:w*0.045,height:resting ? h*0.018 : h*0.065)
                    eye.frame(width:w*0.045,height:resting ? h*0.018 : h*0.065)
                }.foregroundStyle(Color(red:0.12,green:0.3,blue:0.27)).offset(y:h*0.13)
                HStack(spacing:w*0.27) {
                    Ellipse().fill(Color(red:0.96,green:0.62,blue:0.54).opacity(0.72))
                    Ellipse().fill(Color(red:0.96,green:0.62,blue:0.54).opacity(0.72))
                }.frame(width:w*0.5,height:h*0.05).offset(y:h*0.2)
                Path { p in
                    p.move(to:CGPoint(x:w*0.46,y:h*0.68))
                    p.addQuadCurve(to:CGPoint(x:w*0.54,y:h*0.68),control:CGPoint(x:w*0.5,y:h*0.74))
                }.stroke(Color(red:0.12,green:0.3,blue:0.27),style:StrokeStyle(lineWidth:max(1.5,w*0.014),lineCap:.round))
            }
        }.aspectRatio(1,contentMode:.fit).accessibilityLabel("見守り役のしずく、ぽた")
    }
    private var eye: some View { Capsule() }
}
