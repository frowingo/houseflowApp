import SwiftUI

/// Custom slider component for selecting member count
/// Features: Train track style with stops, draggable bubble indicator
struct MemberCountPicker: View {
    @Binding var memberCount: Int
    let minCount: Int = 2
    let maxCount: Int = 8
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.xl) {
            Text("Person Count")
                .font(AppDesign.Typography.headline)
            
            sliderSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Slider Section
    
    private var sliderSection: some View {
        VStack(spacing: AppDesign.Spacing.sm) {
            trainTrackSlider
            sliderLabels
        }
        .padding(.vertical, AppDesign.Spacing.lg)
    }
    
    private var trainTrackSlider: some View {
        GeometryReader { geometry in
            let padding: CGFloat = 22
            let sliderWidth = geometry.size.width - (padding * 2)
            
            ZStack {
                railBackground(width: sliderWidth)
                trainStops(width: sliderWidth)
                floatingBubble(geometry: geometry, sliderWidth: sliderWidth)
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(geometry: geometry, padding: padding, sliderWidth: sliderWidth))
            .onTapGesture { location in
                handleTap(at: location, geometry: geometry, padding: padding, sliderWidth: sliderWidth)
            }
        }
        .frame(height: 70)
    }
    
    // MARK: - Subcomponents
    
    private func railBackground(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color(.systemGray4))
            .frame(width: width, height: 6)
    }
    
    private func trainStops(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(stride(from: minCount, through: maxCount, by: 1)), id: \.self) { count in
                stopIndicator(count: count)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(width: width)
    }
    
    private func stopIndicator(count: Int) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(.systemGray3))
                .frame(width: 3, height: 16)
                .cornerRadius(1.5)
            
            Circle()
                .fill(memberCount >= count ? AppDesign.Colors.primary : Color(.systemGray4))
                .frame(width: 10, height: 10)
                .animation(AppDesign.Animation.quick, value: memberCount)
        }
    }
    
    private func floatingBubble(geometry: GeometryProxy, sliderWidth: CGFloat) -> some View {
        let totalStops = CGFloat(maxCount - minCount + 1)
        let stopWidth = sliderWidth / totalStops
        let stopIndex = CGFloat(memberCount - minCount)
        let stopCenterFromLeft = (stopIndex * stopWidth) + (stopWidth / 2)
        let bubbleX = (geometry.size.width - sliderWidth) / 2 + stopCenterFromLeft
        
        return VStack(spacing: 0) {
            bubbleCircle
            bubbleTail
        }
        .position(x: bubbleX, y: 15)
        .animation(AppDesign.Animation.spring, value: bubbleX)
    }
    
    private var bubbleCircle: some View {
        Text("\(memberCount)")
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 44, height: 44)
            .background(
                Circle()
                    .fill(AppDesign.Colors.primary)
                    .shadow(
                        color: AppDesign.Colors.primary.opacity(0.3),
                        radius: 10,
                        x: 0,
                        y: 4
                    )
            )
    }
    
    private var bubbleTail: some View {
        Triangle()
            .fill(AppDesign.Colors.primary)
            .frame(width: 14, height: 10)
            .offset(y: -1)
    }
    
    private var sliderLabels: some View {
        HStack {
            Text("Min")
                .font(AppDesign.Typography.caption2)
                .foregroundColor(AppDesign.Colors.textSecondary)
            
            Spacer()
            
            Text("Max")
                .font(AppDesign.Typography.caption2)
                .foregroundColor(AppDesign.Colors.textSecondary)
        }
        .padding(.horizontal, AppDesign.Spacing.xs)
    }
    
    // MARK: - Gesture Handlers
    
    private func dragGesture(geometry: GeometryProxy, padding: CGFloat, sliderWidth: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                updateMemberCount(
                    at: value.location,
                    geometry: geometry,
                    padding: padding,
                    sliderWidth: sliderWidth
                )
            }
    }
    
    private func handleTap(at location: CGPoint, geometry: GeometryProxy, padding: CGFloat, sliderWidth: CGFloat) {
        withAnimation(AppDesign.Animation.spring) {
            updateMemberCount(
                at: location,
                geometry: geometry,
                padding: padding,
                sliderWidth: sliderWidth
            )
        }
    }
    
    private func updateMemberCount(at location: CGPoint, geometry: GeometryProxy, padding: CGFloat, sliderWidth: CGFloat) {
        let clampedX = max(padding, min(geometry.size.width - padding, location.x))
        let normalizedPosition = (clampedX - padding) / sliderWidth
        let step = round(normalizedPosition * CGFloat(maxCount - minCount))
        let newCount = Int(step) + minCount
        let clampedCount = max(minCount, min(maxCount, newCount))
        
        if clampedCount != memberCount {
            withAnimation(AppDesign.Animation.spring) {
                memberCount = clampedCount
            }
        }
    }
}

// MARK: - Triangle Shape

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Previews

#Preview("Default") {
    @Previewable @State var count = 3
    
    return MemberCountPicker(memberCount: $count)
        .padding()
}

#Preview("Minimum Value") {
    @Previewable @State var count = 2
    
    return MemberCountPicker(memberCount: $count)
        .padding()
}

#Preview("Maximum Value") {
    @Previewable @State var count = 8
    
    return MemberCountPicker(memberCount: $count)
        .padding()
}

#Preview("Dark Mode") {
    @Previewable @State var count = 5
    
    return MemberCountPicker(memberCount: $count)
        .padding()
        .preferredColorScheme(.dark)
}
