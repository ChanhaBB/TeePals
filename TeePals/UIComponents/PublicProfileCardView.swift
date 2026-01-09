import SwiftUI

/// A reusable card view that displays public profile information.
/// Can be used standalone or in lists (e.g., round participants, search results).
struct PublicProfileCardView: View {
    let profile: PublicProfile
    var style: CardStyle = .full
    
    enum CardStyle {
        case full       // All info, larger layout
        case compact    // Key info only, smaller layout
        case minimal    // Avatar + name only
    }
    
    var body: some View {
        switch style {
        case .full:
            fullCard
        case .compact:
            compactCard
        case .minimal:
            minimalCard
        }
    }
    
    // MARK: - Full Card
    
    private var fullCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Avatar + Name + Location
            HStack(spacing: 12) {
                avatarView(size: 56)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.nickname)
                        .font(.headline)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                        Text(profile.primaryCityLabel)
                            .font(.subheadline)
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let ageDecade = profile.ageDecade {
                    Text(ageDecade.displayText)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .cornerRadius(6)
                }
            }
            
            // Bio
            if let bio = profile.bio, !bio.isEmpty {
                Text(bio)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Stats Row
            if hasGolfStats {
                Divider()
                golfStatsRow
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
    
    // MARK: - Compact Card
    
    private var compactCard: some View {
        HStack(spacing: 12) {
            avatarView(size: 44)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.nickname)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    if let ageDecade = profile.ageDecade {
                        Text(ageDecade.displayText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let skillLevel = profile.skillLevel {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(skillLevel.displayText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if let avgScore = profile.avgScore18 {
                VStack(spacing: 2) {
                    Text("\(avgScore)")
                        .font(.headline)
                    Text("avg")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(10)
    }
    
    // MARK: - Minimal Card
    
    private var minimalCard: some View {
        HStack(spacing: 8) {
            avatarView(size: 32)
            
            Text(profile.nickname)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
    
    // MARK: - Avatar View
    
    private func avatarView(size: CGFloat) -> some View {
        Group {
            if let photoUrl = profile.photoUrl, let url = URL(string: photoUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        avatarPlaceholder
                    case .empty:
                        ProgressView()
                    @unknown default:
                        avatarPlaceholder
                    }
                }
            } else {
                avatarPlaceholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color(.systemGray4))
            .overlay(
                Text(profile.nickname.prefix(1).uppercased())
                    .font(.headline)
                    .foregroundColor(.white)
            )
    }
    
    // MARK: - Golf Stats Row
    
    private var hasGolfStats: Bool {
        profile.avgScore18 != nil ||
        profile.skillLevel != nil ||
        profile.experienceYears != nil ||
        profile.playsPerMonth != nil
    }
    
    private var golfStatsRow: some View {
        HStack(spacing: 16) {
            if let avgScore = profile.avgScore18 {
                statItem(value: "\(avgScore)", label: "Avg Score")
            }
            
            if let skillLevel = profile.skillLevel {
                statItem(value: skillLevel.displayText, label: "Skill")
            }
            
            if let years = profile.experienceYears {
                statItem(value: "\(years)", label: "Yrs Playing")
            }
            
            if let plays = profile.playsPerMonth {
                statItem(value: "\(plays)/mo", label: "Rounds")
            }
            
            Spacer()
        }
    }
    
    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Previews

#Preview("Full Card") {
    PublicProfileCardView(
        profile: .preview,
        style: .full
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Compact Card") {
    PublicProfileCardView(
        profile: .preview,
        style: .compact
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Minimal Card") {
    PublicProfileCardView(
        profile: .preview,
        style: .minimal
    )
    .padding()
}

// MARK: - Preview Helper

extension PublicProfile {
    static var preview: PublicProfile {
        PublicProfile(
            id: "preview-123",
            nickname: "Alex",
            photoUrl: nil,
            gender: .male,
            occupation: "Software Engineer",
            bio: "Weekend golfer trying to break 90. Love morning tee times!",
            primaryCityLabel: "San Jose, CA",
            primaryLocation: GeoLocation(latitude: 37.3382, longitude: -121.8863),
            avgScore18: 94,
            experienceYears: 5,
            playsPerMonth: 3,
            skillLevel: .intermediate,
            ageDecade: .thirties
        )
    }
}

