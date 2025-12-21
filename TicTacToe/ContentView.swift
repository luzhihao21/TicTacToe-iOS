import SwiftUI
import AVFoundation

struct ContentView: View {
    // --- 游戏状态 ---
    @State private var board: [String] = Array(repeating: "", count: 9)
    @State private var isXTurn = true
    @State private var winMessage = ""
    @State private var showWinAlert = false
    @State private var isAIMode = true
    @State private var audioPlayer: AVAudioPlayer?

    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    let winPatterns: [[Int]] = [[0,1,2], [3,4,5], [6,7,8], [0,3,6], [1,4,7], [2,5,8], [0,4,8], [2,4,6]]

    // 经典拟物化底色
    let bgColor = Color(red: 0.9, green: 0.9, blue: 0.93)

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()
            
            VStack(spacing: 25) {
                // 1. 标题区
                VStack(spacing: 12) {
                    Text("三子棋大师")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundColor(.gray)
                        .shadow(color: .white, radius: 1, x: 1, y: 1)
                        .shadow(color: .black.opacity(0.2), radius: 1, x: -1, y: -1)
                    
                    Picker("模式", selection: $isAIMode) {
                        Text("人机对战").tag(true)
                        Text("双人对战").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 40)
                }
                .padding(.top, 20)

                // 2. 状态提示
                Text(isXTurn ? "轮到 X 玩家" : (isAIMode ? "智能手机思考中..." : "轮到 O 玩家"))
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(isXTurn ? .blue : .red)

                // 3. 经典拟物化 3x3 棋盘
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(0..<9) { index in
                        ZStack {
                            // 实体按键感格子
                            RoundedRectangle(cornerRadius: 20)
                                .fill(bgColor)
                                .shadow(color: .black.opacity(0.2), radius: 5, x: 5, y: 5)
                                .shadow(color: .white, radius: 5, x: -5, y: -5)
                            
                            Text(board[index])
                                .font(.system(size: 55, weight: .bold, design: .rounded))
                                .foregroundColor(board[index] == "X" ? .blue : .red)
                        }
                        .frame(height: 100)
                        .onTapGesture {
                            playerMove(at: index)
                        }
                    }
                }
                .padding(30)

                // 4. 重置按钮
                Button(action: {
                    stopSound() // 动作即停：停止音乐
                    resetGame()
                }) {
                    Text("重新开始")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .padding(.vertical, 15)
                        .padding(.horizontal, 40)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(bgColor)
                                .shadow(color: .black.opacity(0.15), radius: 8, x: 8, y: 8)
                                .shadow(color: .white, radius: 8, x: -8, y: -8)
                        )
                }
                Spacer()
            }
        }
        .onChange(of: isAIMode) {
            stopSound() // 动作即停：切换模式停止音乐
            resetGame()
        }
        .alert(winMessage, isPresented: $showWinAlert) {
            Button("再来一局", action: resetGame)
        }
    }

    // --- 逻辑函数 ---

    func playerMove(at index: Int) {
        guard board[index] == "" && winMessage == "" else { return }
        
        stopSound() // 动作即停：点击格子停止之前的胜利音乐
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        board[index] = isXTurn ? "X" : "O"
        
        if checkGameState() { return }
        
        isXTurn.toggle()

        if isAIMode && !isXTurn {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                smartAIMove()
            }
        }
    }

    func smartAIMove() {
        guard winMessage == "" else { return }
        if let move = findBestMove(for: "O") { makeAIMove(at: move); return }
        if let move = findBestMove(for: "X") { makeAIMove(at: move); return }
        if board[4] == "" { makeAIMove(at: 4); return }
        let available = board.indices.filter { board[$0] == "" }
        if let move = available.randomElement() { makeAIMove(at: move) }
    }

    func findBestMove(for player: String) -> Int? {
        for pattern in winPatterns {
            let values = pattern.map { board[$0] }
            if values.filter({ $0 == player }).count == 2 && values.contains("") {
                return pattern[values.firstIndex(of: "")!]
            }
        }
        return nil
    }

    func makeAIMove(at index: Int) {
        board[index] = "O"
        if !checkGameState() {
            isXTurn = true
        }
    }

    func checkGameState() -> Bool {
        if let winner = getWinner() {
            winMessage = "🎉 胜利者是 \(winner)!"
            playWinSound(for: winner)
            showWinAlert = true
            return true
        } else if !board.contains("") {
            winMessage = "🤝 平局！"
            showWinAlert = true
            return true
        }
        return false
    }

    func getWinner() -> String? {
        for p in winPatterns {
            if board[p[0]] != "" && board[p[0]] == board[p[1]] && board[p[1]] == board[p[2]] {
                return board[p[0]]
            }
        }
        return nil
    }

    // --- 声音控制优化 ---

    func playWinSound(for winner: String) {
        let soundName = winner == "X" ? "win_x" : "win_o"
        guard let path = Bundle.main.path(forResource: soundName, ofType: "mp3") else { return }
        let url = URL(fileURLWithPath: path)
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch { print("声音播放失败") }
    }

    func stopSound() {
        // 只要播放器存在且正在播放，就强制停止并重置时间
        if audioPlayer?.isPlaying == true {
            audioPlayer?.stop()
            audioPlayer?.currentTime = 0
        }
    }

    func resetGame() {
        board = Array(repeating: "", count: 9)
        isXTurn = true
        winMessage = ""
    }
}
