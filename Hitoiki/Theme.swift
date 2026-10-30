import SwiftUI
import UIKit

enum Palette {
    static let forest = Color(light:0x244C43,dark:0xBAE9D5)
    static let ink = Color(light:0x253E37,dark:0xEDF5ED)
    static let secondary = Color(light:0x67796F,dark:0xB1C5BA)
    static let canvas = Color(light:0xF6F6EE,dark:0x142720)
    static let card = Color(light:0xFFFFFF,dark:0x21392F)
    static let mint = Color(light:0xDCEEE1,dark:0x2E5140)
    static let peach = Color(light:0xFBE5D5,dark:0x594337)
    static let orange = Color(light:0x865035,dark:0xFFCBAB)
}
private extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor:UIColor { traits in
            let n = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red:CGFloat((n>>16)&255)/255,green:CGFloat((n>>8)&255)/255,blue:CGFloat(n&255)/255,alpha:1)
        })
    }
}

struct SoftCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(22).frame(maxWidth:.infinity,alignment:.leading)
            .background(Palette.card,in:RoundedRectangle(cornerRadius:28))
    }
}
struct FilledButton: ButtonStyle {
    var secondary = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).frame(maxWidth:.infinity).padding(.vertical,18).padding(.horizontal,16)
            .foregroundStyle(secondary ? Palette.forest : Color.white)
            .background(secondary ? Palette.mint : Color(red:0.17,green:0.39,blue:0.32),in:RoundedRectangle(cornerRadius:22))
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}
struct SectionCaption: View {
    var overline: String
    var title: String
    var body: some View {
        VStack(alignment:.leading,spacing:6) {
            Text(overline).font(.system(.caption,design:.rounded,weight:.bold)).tracking(2).foregroundStyle(Palette.secondary)
            Text(title).font(.system(.title2,design:.rounded,weight:.bold)).foregroundStyle(Palette.ink)
        }
    }
}
struct Metric: View {
    var value: String
    var label: String
    var symbol: String
    var body: some View {
        VStack(alignment:.leading,spacing:8) {
            Image(systemName:symbol).font(.title3).foregroundStyle(Palette.forest)
            Text(value).font(.system(.title2,design:.rounded,weight:.bold)).foregroundStyle(Palette.ink).contentTransition(.numericText())
            Text(label).font(.caption).foregroundStyle(Palette.secondary)
        }.frame(maxWidth:.infinity,alignment:.leading)
    }
}
struct WaterToast: View {
    var text: String
    var undo: (() -> Void)?
    var body: some View {
        HStack {
            Image(systemName:"checkmark.circle.fill").foregroundStyle(Palette.forest)
            Text(text).font(.subheadline.weight(.medium))
            Spacer(minLength:4)
            if let undo { Button("取消",action:undo).font(.subheadline.bold()) }
        }.padding(16).background(Palette.card,in:RoundedRectangle(cornerRadius:20)).shadow(color:.black.opacity(0.08),radius:12,y:4).padding(.horizontal,20)
    }
}
