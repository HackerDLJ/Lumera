import SwiftUI

struct HealthGuidanceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Label("Health guidance", systemImage: "heart.text.square.fill")
                    .font(.title.bold())
                    .foregroundStyle(Color.lumeraPrimary)

                guidance(title: "What is anemia?", icon: "info.circle") {
                    Text("Anemia means the blood has less haemoglobin than expected for a person's age, sex, and physiological circumstances. It can have many causes, so identifying a possible low haemoglobin level is only the first step.")
                }
                guidance(title: "If a screening result is concerning", icon: "stethoscope") {
                    Text("A screening result should be confirmed with a standard haemoglobin or complete blood count test and discussed with a qualified healthcare professional.")
                }
                guidance(title: "Nutrition", icon: "leaf") {
                    Text("A balanced diet can include iron-containing foods such as legumes, leafy vegetables, eggs, meat or fish where appropriate, along with vitamin-C-rich foods. Nutrition advice does not replace evaluation of confirmed anemia.")
                }
                guidance(title: "Seek urgent care", icon: "exclamationmark.triangle") {
                    Text("Severe breathlessness, fainting, chest pain, confusion, or other acute symptoms require prompt medical attention rather than relying on a screening app.")
                }
                Text("Lumera is a screening research application. It does not diagnose anemia and does not replace laboratory testing or professional medical evaluation.")
                    .font(.footnote)
                    .foregroundStyle(Color.lumeraSecondaryText)
            }
            .padding()
        }
        .background(Color.lumeraBackground.ignoresSafeArea())
        .navigationTitle("Guidance")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func guidance<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(.headline).foregroundStyle(Color.lumeraText)
            content().font(.subheadline).foregroundStyle(Color.lumeraSecondaryText).fixedSize(horizontal: false, vertical: true)
        }
        .lumeraCard()
    }
}
