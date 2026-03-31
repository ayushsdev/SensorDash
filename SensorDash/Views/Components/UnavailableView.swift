import SwiftUI

struct UnavailableView: View {
    let sensor: String
    var reason: String = "This sensor is not available on your hardware."
    var icon: String = "exclamationmark.triangle"

    var body: some View {
        ContentUnavailableView {
            Label(sensor, systemImage: icon)
        } description: {
            Text(reason)
        }
    }
}
