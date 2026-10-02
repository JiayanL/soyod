import SwiftUI
import PhotosUI

/// Snap entry: camera, photo library, or a bundled sample.
struct SnapPickerSheet: View {
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false

    static let samples = ["chicken_rice_bowl", "salmon_poke", "avocado_toast_eggs", "greek_yogurt_berries", "burger_fries", "pasta", "salad", "protein_oats", "sushi"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    VStack(alignment: .leading, spacing: Theme.Space.xs) {
                        Text("Snap your plate")
                            .textStyle(.displayS)
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Text("Atlas identifies each item on-device and estimates portions. You confirm before anything is logged.")
                            .textStyle(.body)
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    VStack(spacing: Theme.Space.s) {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            Button {
                                showCamera = true
                            } label: {
                                Label("Take photo", systemImage: "camera.fill")
                            }
                            .buttonStyle(.atlasPrimary)
                        }
                        PhotosPicker(selection: $pickerItem, matching: .images) {
                            Label("Choose from library", systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(UIImagePickerController.isSourceTypeAvailable(.camera) ? AnyButtonStyle(SecondaryButtonStyle()) : AnyButtonStyle(PrimaryButtonStyle()))
                        .accessibilityIdentifier("photoLibrary")
                    }
                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        MicroLabel("Or try a sample")
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.Space.xs), GridItem(.flexible(), spacing: Theme.Space.xs), GridItem(.flexible(), spacing: Theme.Space.xs)], spacing: Theme.Space.xs) {
                            ForEach(Self.samples, id: \.self) { name in
                                if let image = SampleMealPhotos.image(named: name) {
                                    Button { open(image) } label: {
                                        Color.clear
                                            .aspectRatio(1, contentMode: .fit)
                                            .overlay {
                                                Image(uiImage: image).resizable().scaledToFill()
                                            }
                                            .clipShape(.rect(cornerRadius: Theme.Radius.small, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Sample: \(name.replacingOccurrences(of: "_", with: " "))")
                                    .accessibilityIdentifier("sample-\(name)")
                                }
                            }
                        }
                    }
                }
                .gutter()
                .padding(.top, Theme.Space.m)
                .padding(.bottom, Theme.Space.xxl)
            }
            .atlasScreenBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        open(image)
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    showCamera = false
                    if let image { open(image) }
                }
                .ignoresSafeArea()
            }
        }
    }

    private func open(_ image: UIImage) {
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            router.sheet = .snapReview(SnapInput(image: image))
        }
    }
}

struct AnyButtonStyle: ButtonStyle {
    private let make: (Configuration) -> AnyView
    init<S: ButtonStyle>(_ style: S) { make = { AnyView(style.makeBody(configuration: $0)) } }
    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}

/// UIKit camera wrapper.
struct CameraPicker: UIViewControllerRepresentable {
    let onFinish: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onFinish: (UIImage?) -> Void
        init(onFinish: @escaping (UIImage?) -> Void) { self.onFinish = onFinish }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onFinish(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onFinish(nil) }
    }
}
