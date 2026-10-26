import SwiftUI

// Shared native surfaces keep contrast and hierarchy consistent in both appearances.
enum DragonTheme {
    static let accent = Color(red:0.51,green:0.40,blue:0.75)
    static let canvas = Color(nsColor:.windowBackgroundColor)
    static let surface = Color(nsColor:.controlBackgroundColor)
}
struct DragonCard:ViewModifier {
    func body(content:Content) -> some View {
        content.padding(18).frame(maxWidth:.infinity,alignment:.leading)
            .background(DragonTheme.surface,in:RoundedRectangle(cornerRadius:18))
            .overlay(RoundedRectangle(cornerRadius:18).strokeBorder(.primary.opacity(0.06)))
    }
}
extension View { func dragonCard() -> some View { modifier(DragonCard()) } }
struct DragonIconButton:ButtonStyle {
    func makeBody(configuration:Configuration) -> some View {
        configuration.label.font(.system(size:13,weight:.medium)).frame(width:30,height:30)
            .background(.primary.opacity(configuration.isPressed ? 0.12:0.05),in:RoundedRectangle(cornerRadius:9))
            .contentShape(RoundedRectangle(cornerRadius:9))
    }
}
struct SectionEyebrow:View {
    let title:String
    var body:some View { Text(title).font(.system(size:11,weight:.semibold)).tracking(1).foregroundStyle(.secondary) }
}
