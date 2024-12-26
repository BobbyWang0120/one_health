//
//  ContentView.swift
//  OneHealth
//
//  Created by Bobby Wang on 12/26/24.
//

// 导入所需的框架
import SwiftUI
import HealthKit

// 定义健康数据模型，存储各项健康指标
struct HealthData {
    var steps: Int = 0          // 步数
    var activeEnergy: Double = 0 // 活动能量消耗（卡路里）
    var sleepHours: Double = 0   // 睡眠时长（小时）
    var heartRate: Double = 0    // 心率（次/分钟）
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
                    // 根据授权状态显示不同的界面
                    if isAuthorized {
                        // 已授权：显示健康数据卡片
                        HealthDataCard(title: "Steps", value: "\(healthData.steps)", icon: "figure.walk")
                        HealthDataCard(title: "Active Energy", value: String(format: "%.1f kcal", healthData.activeEnergy), icon: "flame.fill")
                        HealthDataCard(title: "Sleep", value: String(format: "%.1f hours", healthData.sleepHours), icon: "bed.double.fill")
                        HealthDataCard(title: "Heart Rate", value: String(format: "%.0f BPM", healthData.heartRate), icon: "heart.fill")
                    } else {
                        // 未授权：显示授权请求界面
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
                checkAuthorization() // 界面出现时检查授权状态
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
        // 确保设备支持HealthKit
        guard HKHealthStore.isHealthDataAvailable() else {
            showingAuthError = true
            return
        }
        
        // 定义需要访问的健康数据类型
        let types = Set([
            HKObjectType.quantityType(forIdentifier: .stepCount)!,           // 步数
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!, // 活动能量
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,      // 睡眠分析
            HKObjectType.quantityType(forIdentifier: .heartRate)!           // 心率
        ])
        
        // 获取授权状态
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
        
        // 定义需要访问的健康数据类型
        let types = Set([
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!
        ])
        
        // 请求授权
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
        fetchSteps()
        fetchActiveEnergy()
        fetchSleep()
        fetchHeartRate()
    }
    
    // 获取步数数据
    private func fetchSteps() {
        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        // 创建步数统计查询
        let query = HKStatisticsQuery(quantityType: stepsType,
                                    quantitySamplePredicate: predicate,
                                    options: .cumulativeSum) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else { return }
            DispatchQueue.main.async {
                healthData.steps = Int(sum.doubleValue(for: .count()))
            }
        }
        healthStore.execute(query)
    }
    
    // 获取活动能量消耗数据
    private func fetchActiveEnergy() {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        // 创建活动能量统计查询
        let query = HKStatisticsQuery(quantityType: energyType,
                                    quantitySamplePredicate: predicate,
                                    options: .cumulativeSum) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else { return }
            DispatchQueue.main.async {
                healthData.activeEnergy = sum.doubleValue(for: .kilocalorie())
            }
        }
        healthStore.execute(query)
    }
    
    // 获取睡眠数据
    private func fetchSleep() {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        // 创建睡眠样本查询
        let query = HKSampleQuery(sampleType: sleepType,
                                predicate: predicate,
                                limit: HKObjectQueryNoLimit,
                                sortDescriptors: nil) { _, samples, error in
            guard let samples = samples as? [HKCategorySample] else { return }
            // 计算总睡眠时间（秒）并转换为小时
            let totalSeconds = samples.reduce(0.0) { total, sample in
                total + sample.endDate.timeIntervalSince(sample.startDate)
            }
            DispatchQueue.main.async {
                healthData.sleepHours = totalSeconds / 3600.0
            }
        }
        healthStore.execute(query)
    }
    
    // 获取心率数据
    private func fetchHeartRate() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        // 创建心率统计查询（获取平均心率）
        let query = HKStatisticsQuery(quantityType: heartRateType,
                                    quantitySamplePredicate: predicate,
                                    options: .discreteAverage) { _, result, error in
            guard let result = result, let average = result.averageQuantity() else { return }
            DispatchQueue.main.async {
                healthData.heartRate = average.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            }
        }
        healthStore.execute(query)
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
