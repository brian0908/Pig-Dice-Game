//
//  ContentView.swift
//  Pig Dice Game
//
//  Created by Brian Lee on 11/11/25.
//

import SwiftUI

struct Player: Identifiable {
	let id = UUID()
	var name: String
	var totalScore: Int = 0
	var wins: Int = 0
	var losses: Int = 0
}

enum GameMode: String, CaseIterable, Identifiable {
	case vsFriend = "雙人對戰"
	case vsComputer = "電腦對戰"
	
	var id: String { rawValue }
}

enum DiceMode: String, CaseIterable, Identifiable {
	case one = "1 顆骰子"
	case two = "2 顆骰子"
	
	var id: String { rawValue }
}

struct DiceRulesPopup: View {
	@Binding var isPresented: Bool
	let diceMode: DiceMode
	
	var body: some View {
		ZStack {
			// 半透明黑色當背板，點背景也可以關掉
			Color.black.opacity(0.4)
				.ignoresSafeArea()
				.onTapGesture {
					isPresented = false
				}
			
			VStack(alignment: .leading, spacing: 12) {
				HStack {
					Text(diceMode == .one ? "一顆骰子規則" : "兩顆骰子規則")
						.font(.headline.bold())
					
					Spacer()
					
					Button {
						isPresented = false
					} label: {
						Image(systemName: "xmark.circle.fill")
							.font(.title2)
					}
					.buttonStyle(.plain)
				}
				
				// 依照骰子模式顯示不同規則
				if diceMode == .one {
					Text("• 丟到 1：本回合分數歸零並結束回合")
					Text("• 丟到 2–6：點數加到本回合暫存分數")
					Text("• 玩家可選擇繼續丟 (Roll) 或結束回合 (Hold)，Hold 後本回合分數加到總分")
					Text("• 總分率先達到 100 的玩家獲勝")
				} else {
					Text("• 只有一顆為 1：本回合分數歸零並結束回合")
					Text("• 兩顆都是 1：本回合分數歸零，總分也歸零並結束回合")
					Text("• 兩顆點數一樣且不是 1：必須繼續丟，不能 hold")
					Text("• 總分率先達到 100 的玩家獲勝")
				}
				
				Spacer(minLength: 0)
			}
			.padding(20)
			.frame(maxWidth: 300, maxHeight: 300)
			.glassEffect(in: .rect(cornerRadius: 16.0))
			.shadow(radius: 12)
		}
		.animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPresented)
	}
}

struct PigGameView: View {
	@State private var players: [Player] = [
		Player(name: "Player 1"),
		Player(name: "Player 2")
	]
	
	@State private var gameMode: GameMode = .vsFriend
	@State private var diceMode: DiceMode = .one
	
	@State private var currentPlayerIndex: Int = 0
	@State private var currentTurnPoints: Int = 0
	
	@State private var die1: Int? = nil
	@State private var die2: Int? = nil
	
	@State private var forcedRoll: Bool = false      // 兩顆骰子且雙數（非 1）時必須繼續 roll
	@State private var gameOver: Bool = false
	@State private var winnerIndex: Int? = nil
	
	@State private var isComputerTurn: Bool = false  // 電腦思考中的 flag
	@State private var showDiceRules = false
	
	private let targetScore = 100
	
	var body: some View {
		ZStack {
			// 背景
			Color(red: 0xF1/255, green: 0xF1/255, blue: 0xE9/255)
				.ignoresSafeArea()
			
			VStack(spacing: 24) {
				Text("🐷 Pig Dice Game")
					.font(.largeTitle.bold())
				
				modeSelectors
				scoreBoard
				diceArea
				currentInfo
				controlButtons
			}
			.padding()
			.foregroundStyle(.primary)
			
			// 👇 只有兩顆骰子 & showDiceRules 時顯示 popup
			if showDiceRules {
				DiceRulesPopup(isPresented: $showDiceRules, diceMode: diceMode)
					.transition(.scale.combined(with: .opacity))
					.zIndex(1)
			}
		}
		.onChange(of: gameMode, initial: false) { _, newValue in
			if newValue == .vsComputer {
				players[1].name = "電腦"
			} else {
				players[1].name = "Player 2"
			}
			resetGame(keepStats: true)
		}
		.onChange(of: diceMode, initial: false) { _, newValue in
			resetGame(keepStats: true)
			if newValue == .one {
				showDiceRules = false
			}
		}
	}
	
	// MARK: - Subviews
	
	private var modeSelectors: some View {
		VStack(spacing: 12) {
			HStack {
				Text("對戰模式")
					.fontWeight(.bold)
				Spacer()
			}
			
			Picker("Game Mode", selection: $gameMode) {
				ForEach(GameMode.allCases) { mode in
					Text(mode.rawValue).tag(mode)
				}
			}
			.pickerStyle(.segmented)
			
			HStack {
				Text("骰子模式")
					.fontWeight(.bold)
				Spacer()
			}
			
			Picker("Dice Mode", selection: $diceMode) {
				ForEach(DiceMode.allCases) { mode in
					Text(mode.rawValue).tag(mode)
				}
			}
			.pickerStyle(.segmented)
		}
		.padding()
		.glassEffect(in: .rect(cornerRadius: 16.0))
	}
	
	private var scoreBoard: some View {
		HStack(spacing: 16) {
			playerPanel(index: 0)
			playerPanel(index: 1)
		}
	}
	
	private func playerPanel(index: Int) -> some View {
		let player = players[index]
		let isCurrent = currentPlayerIndex == index && !gameOver
		
		return VStack(spacing: 8) {
			Text(player.name)
				.font(.title3.bold())
			
			Text("分數：\(player.totalScore)")
				.font(.headline)
			
			Text("戰績：\(player.wins) 勝 \(player.losses) 敗")
				.font(.caption)
			
			if isCurrent {
				Text("🎯 正在出手")
					.font(.caption.bold())
					.padding(.horizontal, 8)
					.padding(.vertical, 4)
					.background(.yellow.opacity(0.8))
					.clipShape(Capsule())
			}
		}
		.padding()
		.frame(maxWidth: .infinity)
		.glassEffect(in: .rect(cornerRadius: 16.0))
		.overlay(
			RoundedRectangle(cornerRadius: 16)
				.stroke(isCurrent ? Color.orange : Color.clear, lineWidth: 2)
		)
	}
	
	private var diceArea: some View {
		VStack(spacing: 12) {
			HStack(spacing: 24) {
				DieView(value: die1)
				
				if diceMode == .two {
					DieView(value: die2)
				}
			}
		}
		.padding()
		.glassEffect(in:.rect(cornerRadius: 16.0))
	}
	
	private var currentInfo: some View {
		VStack(spacing: 8) {
			// 玻璃卡片本體
			VStack(spacing: 4) {
				Text("目前玩家：\(players[currentPlayerIndex].name)")
					.font(.headline)
				
				Text("本回合暫存分數：\(currentTurnPoints)")
					.font(.subheadline)
				
				if gameOver, let winnerIndex {
					Text("🎉 Winner: \(players[winnerIndex].name)！")
						.font(.headline.bold())
						.foregroundColor(.orange)
						.padding(.top, 4)
				} else if isComputerTurn {
					Text("Computer 正在思考…")
						.font(.caption)
						.foregroundColor(.secondary)
						.padding(.top, 4)
				}
			}
			.padding()
			.glassEffect(in: .rect(cornerRadius: 16.0))

			HStack {
				Spacer()
				Button {
					showDiceRules = true
				} label: {
					Label(diceMode == .one ? "一顆骰子規則" : "兩顆骰子規則",
						  systemImage: "info.circle")
						.font(.caption)
				}
			}
		}
	}
	
	private var controlButtons: some View {
		HStack(spacing: 16) {
			// Roll
			Button {
				rollButtonTapped()
			} label: {
				Label("Roll", systemImage: "dice")
					.frame(maxWidth: .infinity)
					.foregroundStyle(.white)
			}
			.buttonStyle(.glassProminent)
			.tint(.blue)
			.disabled(gameOver || isComputerTurn)
			
			// Hold
			Button {
				holdButtonTapped()
			} label: {
				Label("Hold", systemImage: "hand.raised.fill")
					.frame(maxWidth: .infinity)
					// 這裡用 canHold 決定文字顏色
					.foregroundStyle(canHold ? Color.white : Color.black)
			}
			.buttonStyle(.glassProminent)
			.tint(.blue)
			.disabled(!canHold)
			
			// Replay
			Button {
				resetGame(keepStats: true)
			} label: {
				Label("Restart", systemImage: "arrow.counterclockwise")
					.frame(maxWidth: .infinity)
			}
			.buttonStyle(.glassProminent)
			.tint(.clear)
		}
	}
	
	// MARK: - Game Logic
	
	private var canHold: Bool {
		!gameOver &&
		!isComputerTurn &&
		currentTurnPoints > 0 &&
		!forcedRoll
	}
	
	private func resetGame(keepStats: Bool) {
		for i in players.indices {
			players[i].totalScore = 0
			if !keepStats {
				players[i].wins = 0
				players[i].losses = 0
			}
		}
		currentPlayerIndex = 0
		currentTurnPoints = 0
		die1 = nil
		die2 = nil
		forcedRoll = false
		gameOver = false
		winnerIndex = nil
		isComputerTurn = false
		
		checkForComputerTurn()
	}
	
	private func rollButtonTapped() {
		guard !gameOver else { return }
		rollDice()
	}
	
	private func holdButtonTapped() {
		guard canHold else { return }
		hold()
	}
	
	private func rollDice() {
		guard !gameOver else { return }
		
		let d1 = Int.random(in: 1...6)
		die1 = d1
		
		switch diceMode {
		case .one:
			handleOneDieRoll(d1)
		case .two:
			let d2 = Int.random(in: 1...6)
			die2 = d2
			handleTwoDiceRoll(d1: d1, d2: d2)
		}
	}
	
	private func handleOneDieRoll(_ value: Int) {
		if value == 1 {
			// 本回合分數歸零，結束回合
			currentTurnPoints = 0
			forcedRoll = false
			endTurn()
		} else {
			currentTurnPoints += value
		}
	}
	
	private func handleTwoDiceRoll(d1: Int, d2: Int) {
		if d1 == 1 && d2 == 1 {
			// 雙 1：本回合分數歸零，總分也歸零，結束回合
			currentTurnPoints = 0
			players[currentPlayerIndex].totalScore = 0
			forcedRoll = false
			endTurn()
		} else if d1 == 1 || d2 == 1 {
			// 只有一顆為 1：本回合分數歸零，結束回合
			currentTurnPoints = 0
			forcedRoll = false
			endTurn()
		} else {
			let sum = d1 + d2
			currentTurnPoints += sum
			
			if d1 == d2 {
				// 雙數且不是 1：必須繼續丟
				forcedRoll = true
			} else {
				forcedRoll = false
			}
		}
	}
	
	private func hold() {
		guard !gameOver else { return }
		guard currentTurnPoints > 0 else { return }
		
		players[currentPlayerIndex].totalScore += currentTurnPoints
		
		if players[currentPlayerIndex].totalScore >= targetScore {
			// 達到或超過 100 分，獲勝
			gameOver = true
			winnerIndex = currentPlayerIndex
			updateStatsForWin(winner: currentPlayerIndex)
			forcedRoll = false
			return
		}
		
		// 尚未獲勝，結束回合換人
		currentTurnPoints = 0
		forcedRoll = false
		endTurn()
	}
	
	private func endTurn() {
		currentTurnPoints = 0
		forcedRoll = false
		currentPlayerIndex = (currentPlayerIndex + 1) % 2
		checkForComputerTurn()
	}
	
	private func updateStatsForWin(winner: Int) {
		let loser = (winner + 1) % 2
		players[winner].wins += 1
		players[loser].losses += 1
	}
	
	// MARK: - Computer AI
	
	private func checkForComputerTurn() {
		guard gameMode == .vsComputer,
			  currentPlayerIndex == 1,
			  !gameOver else { return }
		
		startComputerTurn()
	}
	
	private func startComputerTurn() {
		guard !isComputerTurn else { return }
		isComputerTurn = true
		
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
			computerTurnStep()
		}
	}
	
	private func computerTurnStep() {
		guard gameMode == .vsComputer,
			  currentPlayerIndex == 1,
			  !gameOver else {
			isComputerTurn = false
			return
		}
		
		let riskThreshold: Int = (diceMode == .one) ? 20 : 18
		let computerTotal = players[1].totalScore
		let potential = computerTotal + currentTurnPoints
		
		let shouldHold = !forcedRoll &&
			currentTurnPoints > 0 &&
			(potential >= targetScore || currentTurnPoints >= riskThreshold)
		
		if shouldHold {
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
				hold()
				self.isComputerTurn = false
			}
		} else {
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
				self.rollDice()
				
				if self.gameMode == .vsComputer,
				   self.currentPlayerIndex == 1,
				   !self.gameOver {
					self.computerTurnStep()
				} else {
					self.isComputerTurn = false
				}
			}
		}
	}
}

// MARK: - Dice View

struct DieView: View {
	let value: Int?
	
	var body: some View {
		ZStack {
			RoundedRectangle(cornerRadius: 18)
				.fill(.ultraThinMaterial)
				.frame(width: 80, height: 80)
				.shadow(radius: 4)
			
			let symbolName = value.map { "die.face.\($0).fill" } ?? "questionmark.square.fill"
			
			Image(systemName: symbolName)
				.resizable()
				.scaledToFit()
				.padding(12)
		}
	}
}

#Preview {
	PigGameView()
}
