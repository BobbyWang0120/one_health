//
//  ContentView.swift
//  OneHealth
//
//  Created by Bobby Wang on 12/26/24.
//

// 导入所需的框架
import SwiftUI
import HealthKit

// 定义睡眠数据模型
struct SleepData {
    var bedTime: Date?          // 上床时间
    var wakeTime: Date?         // 起床时间
    var sleepHours: Double      // 睡眠时长（小时）
    var date: Date              // 日期
}

// 定义健身数据模型
struct WorkoutData {
    var duration: TimeInterval  // 运动时长
    var energyBurned: Double    // 消耗的卡路里
    var workoutType: String     // 运动类型
    var date: Date              // 日期
}

// 定义健康数据模型，存储各项健康指标
struct HealthData {
    var sleepRecords: [SleepData] = []      // 睡眠记录
    var workoutRecords: [WorkoutData] = []   // 健身记录
    var todaySleep: SleepData?              // 今日睡眠数据
    var todayWorkout: WorkoutData?          // 今日健身数据
}

struct ContentView: View {
    // 状态管理
    @State private var healthData = HealthData()     // 健康数据状态
    @State private var isAuthorized = false         // 授权状态
    @State private var showingAuthError = false     // 错误提示状态
    private let healthStore = HKHealthStore()       // HealthKit存储实例
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if isAuthorized {
                        // 今日睡眠数据卡片
                        if let sleepData = healthData.todaySleep {
                            HealthDataCard(title: "Today's Sleep",
                                         value: String(format: "%.1f hours", sleepData.sleepHours),
                                         icon: "bed.double.fill")
                            
                            if let bedTime = sleepData.bedTime {
                                Text("Bed Time: \(formatTime(bedTime))")
                                    .font(.subheadline)
                            }
                            if let wakeTime = sleepData.wakeTime {
                                Text("Wake Time: \(formatTime(wakeTime))")
                                    .font(.subheadline)
                            }
                        }
                        
                        // 今日健身数据卡片
                        if let workoutData = healthData.todayWorkout {
                            HealthDataCard(title: "Today's Workout",
                                         value: String(format: "%.1f kcal", workoutData.energyBurned),
                                         icon: "flame.fill")
                            Text("Duration: \(formatDuration(workoutData.duration))")
                                .font(.subheadline)
                            Text("Activity: \(workoutData.workoutType)")
                                .font(.subheadline)
                        }
                        
                        // 历史数据概览
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Recent Sleep History")
                                .font(.headline)
                            ForEach(healthData.sleepRecords.prefix(5), id: \.date) { sleep in
                                Text("\(formatDate(sleep.date)): \(String(format: "%.1f hrs", sleep.sleepHours))")
                                    .font(.subheadline)
                            }
                        }
                        .padding()
                        .background(.gray.opacity(0.1))
                        .cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Recent Workout History")
                                .font(.headline)
                            ForEach(healthData.workoutRecords.prefix(5), id: \.date) { workout in
                                Text("\(formatDate(workout.date)): \(workout.workoutType) - \(String(format: "%.1f kcal", workout.energyBurned))")
                                    .font(.subheadline)
                            }
                        }
                        .padding()
                        .background(.gray.opacity(0.1))
                        .cornerRadius(10)
                    } else {
                        // 未授权界面保持不变
                        VStack(spacing: 16) {
                            Image(systemName: "heart.text.square.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                            
                            Text("Health Data Access Required")
                                .font(.headline)
                            
                            Text("Please authorize access to your health data to see your health metrics.")
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            Button("Authorize Access") {
                                requestAuthorization()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("Health Dashboard")
            .onAppear {
                checkAuthorization()
            }
            .alert("Authorization Error", isPresented: $showingAuthError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Unable to access HealthKit. Please ensure Health access is enabled in Settings.")
            }
        }
    }
    
    // 检查HealthKit授权状态
    private func checkAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            showingAuthError = true
            return
        }
        
        // 定义需要访问的健康数据类型
        let types = Set([
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,      // 睡眠分析
            HKObjectType.workoutType(),                                     // 体能训练
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)! // 活动能量
        ])
        
        healthStore.getRequestStatusForAuthorization(toShare: [], read: types) { (status, error) in
            DispatchQueue.main.async {
                isAuthorized = status == .unnecessary
                if isAuthorized {
                    fetchHealthData()
                }
            }
        }
    }
    
    // 请求HealthKit授权
    private func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            showingAuthError = true
            return
        }
        
        let types = Set([
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ])
        
        healthStore.requestAuthorization(toShare: [], read: types) { success, error in
            DispatchQueue.main.async {
                isAuthorized = success
                if success {
                    fetchHealthData()
                } else {
                    showingAuthError = true
                }
            }
        }
    }
    
    // 获取所有健康数据
    private func fetchHealthData() {
        fetchSleepData()
        fetchWorkoutData()
    }
    
    // 获取睡眠数据
    private func fetchSleepData() {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        
        // 查询过去30天的睡眠数据
        let calendar = Calendar.current
        let now = Date()
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: thirtyDaysAgo, end: now, options: .strictStartDate)
        
        let query = HKSampleQuery(sampleType: sleepType,
                                predicate: predicate,
                                limit: HKObjectQueryNoLimit,
                                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, samples, error in
            guard let samples = samples as? [HKCategorySample] else { return }
            
            // 按日期分组处理睡眠数据
            let sleepRecords = processSleepSamples(samples)
            DispatchQueue.main.async {
                healthData.sleepRecords = sleepRecords
                healthData.todaySleep = sleepRecords.first
            }
        }
        healthStore.execute(query)
    }
    
    // 处理睡眠样本数据
    private func processSleepSamples(_ samples: [HKCategorySample]) -> [SleepData] {
        let calendar = Calendar.current
        var sleepByDate: [Date: [HKCategorySample]] = [:]
        
        // 按日期分组
        for sample in samples {
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: sample.startDate)
            if let date = calendar.date(from: dateComponents) {
                if sleepByDate[date] == nil {
                    sleepByDate[date] = []
                }
                sleepByDate[date]?.append(sample)
            }
        }
        
        // 处理每天的睡眠数据
        return sleepByDate.map { date, dailySamples in
            var sleepData = SleepData(sleepHours: 0, date: date)
            var totalSleepSeconds = 0.0
            
            // 找出最早的入睡时间和最晚的起床时间
            let sortedSamples = dailySamples.sorted { $0.startDate < $1.startDate }
            sleepData.bedTime = sortedSamples.first?.startDate
            sleepData.wakeTime = sortedSamples.last?.endDate
            
            // 计算总睡眠时间
            for sample in dailySamples {
                totalSleepSeconds += sample.endDate.timeIntervalSince(sample.startDate)
            }
            sleepData.sleepHours = totalSleepSeconds / 3600.0
            
            return sleepData
        }.sorted { $0.date > $1.date }
    }
    
    // 获取健身数据
    private func fetchWorkoutData() {
        // 查询过去30天的健身数据
        let calendar = Calendar.current
        let now = Date()
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: thirtyDaysAgo, end: now, options: .strictStartDate)
        
        let query = HKSampleQuery(sampleType: .workoutType(),
                                predicate: predicate,
                                limit: HKObjectQueryNoLimit,
                                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, samples, error in
            guard let workouts = samples as? [HKWorkout] else { return }
            
            let workoutRecords = workouts.map { workout in
                WorkoutData(
                    duration: workout.duration,
                    energyBurned: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0,
                    workoutType: workout.workoutActivityType.name,
                    date: workout.startDate
                )
            }
            
            DispatchQueue.main.async {
                healthData.workoutRecords = workoutRecords
                healthData.todayWorkout = workoutRecords.first
            }
        }
        healthStore.execute(query)
    }
    
    // 格式化时间
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    // 格式化时长
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        return String(format: "%dh %dm", hours, minutes)
    }
}

// 扩展HKWorkoutActivityType以获取可读性更好的名称
extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .walking: return "Walking"
        case .swimming: return "Swimming"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining: return "Strength Training"
        default: return "Other"
        }
    }
}

// 健康数据卡片视图组件
struct HealthDataCard: View {
    let title: String   // 卡片标题
    let value: String   // 数据值
    let icon: String    // SF Symbols图标名称
    
    var body: some View {
        VStack {
            HStack {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(.blue)
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(value)
                        .font(.title2)
                        .bold()
                        .foregroundColor(.primary)
                }
                Spacer()
            }
            .padding()
        }
        .background(.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

// SwiftUI预览
#Preview {
    ContentView()
}
