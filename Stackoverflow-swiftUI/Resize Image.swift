https://stackoverflow.com/questions/56505692/how-to-resize-image-with-swiftui

Image(room.thumbnailImage)
    .resizable()
    .frame(width: 32.0, height: 32.0)
    
    
struct ResizedImage: View {
    var body: some View {

            Image("myImage")
                .resizable()
                .scaledToFit()
                .frame(width: 200.0,height:200)

    }
}
