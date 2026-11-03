import AppKit
import UserNotifications

/// Shows system notifications, and plays Persepolis's notification sounds.
final class Notifier {
    enum Sound: String {
        case ok
        case fail
        case warning
        case queue
    }

    /// Kept while playing, because a released sound stops.
    private var currentSound: NSSound?

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }

    func send(title: String, body: String, sound: Sound?, playsSounds: Bool, volumePercent: Int) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)

        guard playsSounds, let sound,
              let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav"),
              let player = NSSound(contentsOf: url, byReference: true)
        else { return }
        player.volume = Float(volumePercent) / 100
        player.play()
        currentSound = player
    }
}
