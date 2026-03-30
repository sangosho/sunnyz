//
//  ConfettiView.swift
//  SunnyZ
//
//  Confetti celebration animation for achievements
//

import SwiftUI
import CoreGraphics

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @Binding var isActive: Bool
    private let particleCount = 100

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                ConfettiParticleView(particle: particle)
            }
        }
        .onChange(of: isActive) { newValue in
            if newValue {
                startConfetti()
            } else {
                // Clear particles when animation is deactivated
                particles.removeAll()
            }
        }
        .onDisappear {
            // Clear particles to stop any ongoing animations
            particles.removeAll()
        }
    }

    private func startConfetti() {
        let screenWidth = NSScreen.main?.frame.width ?? 800
        particles = (0..<particleCount).map { _ in
            ConfettiParticle(
                x: CGFloat.random(in: 0...screenWidth),
                y: -CGFloat.random(in: 0...200),
                color: randomColor(),
                size: CGFloat.random(in: 5...15),
                speed: Double.random(in: 200...500),
                rotationSpeed: Double.random(in: -10...10),
                wobble: Double.random(in: 0...10),
                wobbleSpeed: Double.random(in: 0.02...0.1)
            )
        }
    }

    private func randomColor() -> Color {
        let colors: [Color] = [
            .red, .orange, .yellow, .green, .blue, .purple, .pink,
            Color(red: 1.0, green: 0.8, blue: 0.0), // Gold
            Color(red: 1.0, green: 0.4, blue: 0.7)  // Pink
        ]
        return colors.randomElement() ?? .yellow
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var color: Color
    var size: CGFloat
    var speed: Double
    var rotationSpeed: Double
    var rotation: Double = 0
    var wobble: Double
    var wobbleSpeed: Double
    var wobbleOffset: Double = 0
}

struct ConfettiParticleView: View {
    let particle: ConfettiParticle
    @State private var y: CGFloat
    @State private var rotation: Double
    @State private var wobbleOffset: Double
    @State private var isAnimating = false

    init(particle: ConfettiParticle) {
        self.particle = particle
        self._y = State(initialValue: particle.y)
        self._rotation = State(initialValue: particle.rotation)
        self._wobbleOffset = State(initialValue: particle.wobbleOffset)
    }

    var body: some View {
        Rectangle()
            .fill(particle.color)
            .frame(width: particle.size, height: particle.size)
            .rotationEffect(.degrees(rotation))
            .offset(x: particle.wobble * sin(wobbleOffset))
            .offset(y: y)
            .onAppear {
                guard !isAnimating else { return }
                isAnimating = true
                let screenHeight = NSScreen.main?.frame.height ?? 600
                // Use explicit animation with completion to prevent mid-transaction deallocation
                withAnimation(
                    .linear(duration: 3.0)
                ) {
                    y = screenHeight + 100
                    rotation += 720
                    wobbleOffset += 20
                }
            }
            .onDisappear {
                isAnimating = false
                // Reset animation state to prevent Core Animation issues
                y = particle.y
                rotation = particle.rotation
                wobbleOffset = particle.wobbleOffset
            }
    }
}

// MARK: - Preview

struct ConfettiView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack {
                Text("🎉 Achievement Unlocked! 🎉")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()

                Text("You touched grass!")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding()
            .background(Color.black.opacity(0.7))
            .cornerRadius(16)

            ConfettiView(isActive: .constant(true))
        }
        .frame(width: 400, height: 400)
    }
}
