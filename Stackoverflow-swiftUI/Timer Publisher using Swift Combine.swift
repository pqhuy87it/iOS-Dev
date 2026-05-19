https://stackoverflow.com/questions/57199922/create-a-timer-publisher-using-swift-combine/57201744#57201744

import SwiftUI
import Combine

class MyTimer {
    let currentTimePublisher = Timer.TimerPublisher(interval: 1.0, runLoop: .main, mode: .default)
    let cancellable: AnyCancellable?

    init() {
        self.cancellable = currentTimePublisher.connect() as? AnyCancellable
    }

    deinit {
        self.cancellable?.cancel()
    }
}

let timer = MyTimer()

struct Clock : View {
  @State private var currentTime: Date = Date()

  var body: some View {
    VStack {
      Text("\(currentTime)")
    }
    .onReceive(timer.currentTimePublisher) { newCurrentTime in
      self.currentTime = newCurrentTime
    }
  }
}
