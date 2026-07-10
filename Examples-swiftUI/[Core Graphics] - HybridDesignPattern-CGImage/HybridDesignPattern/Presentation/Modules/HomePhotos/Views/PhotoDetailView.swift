import SwiftUI

struct PhotoDetailView: View {
    @Environment(\.viewModelFactory) var factory

    @StateObject private var viewModel: PhotoDetailViewModel

    init(viewModel: PhotoDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Load large size image (regular) for detail
                ImageView(viewModel: factory.makeImageViewModel(url: viewModel.imageURL))
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .cornerRadius(16)
                    .shadow(radius: 5)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    // Display author
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.gray)
                        Text(viewModel.authorName)
                            .font(.headline)
                    }

                    // Display photo description (if any)
                    if let description = viewModel.description {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }

                    // Original photo size
                    Text(viewModel.sizeText)
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Photo Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}
