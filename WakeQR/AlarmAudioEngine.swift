import Foundation
import AVFoundation
import MediaPlayer
import UIKit

/// Plan B audio core.
/// Keep-alive: loops a near-silent file with the `audio` background mode so iOS never suspends us.
/// Alarm: loops the loud alarm file with `.playback` category, which plays over the silent switch.
final class AlarmAudioEngine {

    private var player: AVAudioPlayer?
    private var volumeTimer: Timer?

    private func url(_ name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "wav")
    }

    func startKeepAlive() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { }
        guard let u = url("silence") else { return }
        player?.stop()
        player = try? AVAudioPlayer(contentsOf: u)
        player?.numberOfLoops = -1
        player?.volume = 1.0
        player?.play()
    }

    func startAlarm() {
        do {
            // Drop .mixWithOthers so the alarm takes over the audio route at full force.
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { }
        guard let u = url("alarm") else { return }
        player?.stop()
        player = try? AVAudioPlayer(contentsOf: u)
        player?.numberOfLoops = -1
        player?.volume = 1.0
        player?.play()

        // Re-push the media volume to max every few seconds (Alarmy-style).
        maxOutSystemVolume()
        volumeTimer?.invalidate()
        let t = Timer(timeInterval: 3.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.maxOutSystemVolume() }
        }
        RunLoop.main.add(t, forMode: .common)
        volumeTimer = t
    }

    func stopAll() {
        volumeTimer?.invalidate()
        volumeTimer = nil
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    /// Sets the system media volume to 1.0 via MPVolumeView's slider (works while foregrounded).
    private func maxOutSystemVolume() {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first else { return }
        let volumeView = MPVolumeView(frame: CGRect(x: -200, y: -200, width: 10, height: 10))
        volumeView.alpha = 0.01
        window.addSubview(volumeView)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if let slider = volumeView.subviews.compactMap({ $0 as? UISlider }).first {
                slider.value = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                volumeView.removeFromSuperview()
            }
        }
    }
}
