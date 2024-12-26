//
//  ContentView.swift
//  OneHealth
//
//  Created by Bobby Wang on 12/26/24.
//

import SwiftUI
import HealthKit

struct HealthData {
    var steps: Int = 0
    var activeEnergy: Double = 0
    var sleepHours: Double = 0
    var heartRate: Double = 0
}

struct ContentView: View {
    @State private var healthData = HealthData()
    @State private var isAuthorized = false
    @State private var showingAuthError = false
    private let healthStore = HKHealthStore()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if isAuthorized {
                        // Health Data Cards
                        HealthDataCard(title: "Steps", value: "\(healthData.steps)", icon: "figure.walk")
                        HealthDataCard(title: "Active Energy", value: String(format: "%.1f kcal", healthData.activeEnergy), icon: "flame.fill")
                        HealthDataCard(title: "Sleep", value: String(format: "%.1f hours", healthData.sleepHours), icon: "bed.double.fill")
                        HealthDataCard(title: "Heart Rate", value: String(format: "%.0f BPM", healthData.heartRate), icon: "heart.fill")
                    } else {
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
    
    private func checkAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            showingAuthError = true
            return
        }
        
        let types = Set([
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!
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
    
    private func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            showingAuthError = true
            return
        }
        
        let types = Set([
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!
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
    
    private func fetchHealthData() {
        fetchSteps()
        fetchActiveEnergy()
        fetchSleep()
        fetchHeartRate()
    }
    
    private func fetchSteps() {
        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
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
    
    private func fetchActiveEnergy() {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
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
    
    private func fetchSleep() {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        let query = HKSampleQuery(sampleType: sleepType,
                                predicate: predicate,
                                limit: HKObjectQueryNoLimit,
                                sortDescriptors: nil) { _, samples, error in
            guard let samples = samples as? [HKCategorySample] else { return }
            let totalSeconds = samples.reduce(0.0) { total, sample in
                total + sample.endDate.timeIntervalSince(sample.startDate)
            }
            DispatchQueue.main.async {
                healthData.sleepHours = totalSeconds / 3600.0
            }
        }
        healthStore.execute(query)
    }
    
    private func fetchHeartRate() {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
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

struct HealthDataCard: View {
    let title: String
    let value: String
    let icon: String
    
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

#Preview {
    ContentView()
}
