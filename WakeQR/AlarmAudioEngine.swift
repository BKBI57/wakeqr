import Foundation
import AVFoundation
import MediaPlayer
import UIKit

/// Plan B audio core.
/// Keep-alive: loops a near-silent file with the `audio` background mode so iOS never suspends us.
/// Alarm: loops the loud alarm file with `.playback` category, which plays over the silent switch.
/// While the alarm is active, nothing on the phone stops it except AppModel (i.e. the QR scan):
/// dismissing notifications, opening other apps, or locking the screen leave it ringing,
/// and system audio interruptions (calls etc.) restart it automatically.
final class AlarmAudioEngine {

    private var player: AVAudioPlayer?
    private var previewPlayer: AVAudioPlayer?
    private var volumeTimer: Timer?
    private var alarmVolume: Float = 1.0
    private var alarmSound = "alarm_classic"
    private var alarmActive = false

    /// Fade-in: the alarm opens at `rampFloor` of the chosen level and reaches full over
    /// `rampDuration`. Gentler to wake to, and still unmissable within half a minute.
    private static let rampDuration: TimeInterval = 30
    private static let rampFloor: Float = 0.2
    private var rampStart: Date?
    private var tick = 0

    /// The level to apply right now, somewhere between `rampFloor` and the chosen volume.
    private var rampedVolume: Float {
        guard let rampStart else { return alarmVolume }
        let p = Float(min(1.0, Date().timeIntervalSince(rampStart) / Self.rampDuration))
        return alarmVolume * (Self.rampFloor + (1 - Self.rampFloor) * p)
    }

    init() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            self?.handleInterruption(note)
        }
    }

    private func url(_ name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "wav")
    }

    func startKeepAlive() {
        alarmActive = false
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

    func startAlarm(soundNamed sound: String, volume: Float) {
        alarmSound = sound
        alarmVolume = min(max(volume, 0.3), 1.0)
        alarmActive = true
        rampStart = Date()
        tick = 0
        playAlarmSound()

        // Re-push the media volume every few seconds (Alarmy-style) so the volume buttons can't
        // silence the alarm. Ticking every second keeps the fade-in smooth; the system-volume
        // push stays on its ~3s cadence because each one spins up a throwaway MPVolumeView.
        pushSystemVolume()
        volumeTimer?.invalidate()
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.player?.volume = self.rampedVolume
                self.tick += 1
                if self.tick % 3 == 0 { self.pushSystemVolume() }
                // Belt and suspenders: if anything stopped playback, restart it.
                if self.alarmActive, self.player?.isPlaying != true {
                    self.playAlarmSound()
                }
            }
        }
        RunLoop.main.add(t, forMode: .common)
        volumeTimer = t
    }

    private func playAlarmSound() {
        do {
            // Drop .mixWithOthers so the alarm takes over the audio route at full force.
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { }
        guard let u = url(alarmSound) else { return }
        player?.stop()
        player = try? AVAudioPlayer(contentsOf: u)
        player?.numberOfLoops = -1
        player?.volume = rampedVolume
        player?.play()
    }

    /// Short in-app preview of a tone (setup screen). Toggles off when called for a playing tone.
    func togglePreview(soundNamed sound: String, volume: Float) -> Bool {
        if previewPlayer?.isPlaying == true {
            previewPlayer?.stop()
            previewPlayer = nil
            return false
        }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        guard let u = url(sound) else { return false }
        previewPlayer = try? AVAudioPlayer(contentsOf: u)
        previewPlayer?.volume = min(max(volume, 0.3), 1.0)
        previewPlayer?.play()
        return true
    }

    func stopPreview() {
        previewPlayer?.stop()
        previewPlayer = nil
    }

    func stopAll() {
        alarmActive = false
        rampStart = nil
        volumeTimer?.invalidate()
        volumeTimer = nil
        player?.stop()
        player = nil
        previewPlayer?.stop()
        previewPlayer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    /// A call or Siri can pause our audio; the moment the interruption ends, ring again.
    private func handleInterruption(_ note: Notification) {
        guard alarmActive,
              let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        if type == .ended {
            playAlarmSound()
        }
    }

    /// Sets the system media volume to the chosen alarm level via MPVolumeView's slider
    /// (works while the app is foregrounded).
    private func pushSystemVolume() {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first else { return }
        let volumeView = MPVolumeView(frame: CGRect(x: -200, y: -200, width: 10, height: 10))
        volumeView.alpha = 0.01
        window.addSubview(volumeView)
        let target = rampedVolume
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if let slider = volumeView.subviews.compactMap({ $0 as? UISlider }).first {
                slider.value = target
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                volumeView.removeFromSuperview()
            }
        }
    }
}
