//
//  ContentView.swift
//  AviationWeatherApp
//
//  Created by Francis Ibok on 30/09/2025.
//

import SwiftUI
import CoreData
import Foundation

// MARK: - Main View
struct ContentView: View {
    @StateObject private var viewModel = WeatherViewModel()
    @State private var icaoCode = "LSZH"
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                inputSection
                
                if viewModel.metarData.isEmpty && !viewModel.isLoading {
                    emptyStateView
                } else {
                    weatherList
                }
                
                if let errorMessage = viewModel.errorMessage {
                    errorView(message: errorMessage)
                }
            }
            .navigationTitle("Aviation Weather")
            .overlay {
                if viewModel.isLoading {
                    loadingOverlay
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    refreshButton
                }
            }
            .onAppear {
                viewModel.loadSavedMetars()
            }
        }
    }
    
    // MARK: - View Components
    private var inputSection: some View {
        VStack(spacing: 12) {
            TextField("Enter ICAO Code (e.g., LSZH)", text: $icaoCode)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($isTextFieldFocused)
                .onSubmit {
                    viewModel.fetchMetar(icao: icaoCode)
                }
            
            Button {
                viewModel.fetchMetar(icao: icaoCode)
                isTextFieldFocused = false
            } label: {
                HStack {
                    Image(systemName: "cloud.sun.fill")
                    Text("Fetch Weather")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .disabled(icaoCode.isEmpty || viewModel.isLoading)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "cloud.slash")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            
            Text("No Weather Data")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Enter an ICAO code and tap 'Fetch Weather' to see METAR data")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var weatherList: some View {
        List {
            ForEach(viewModel.metarData) { metar in
                MetarRowView(metar: metar)
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private func errorView(message: String) -> some View {
        VStack {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemGroupedBackground))
        }
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
            
            ProgressView("Fetching METAR...")
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .shadow(radius: 10)
        }
    }
    
    private var refreshButton: some View {
        Button {
            viewModel.loadSavedMetars()
        } label: {
            Image(systemName: "arrow.clockwise")
        }
    }
}

// MARK: - METAR Row View
struct MetarRowView: View {
    let metar: Metar
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerSection
            Divider()
            dataSection
            
            if let rawText = metar.rawText {
                rawTextSection(rawText)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var headerSection: some View {
        HStack {
            Image(systemName: "airplane.circle.fill")
                .foregroundStyle(.blue)
                .font(.title2)
            
            Text(metar.stationId)
                .font(.headline)
            
            Spacer()
            
            if let timestamp = metar.observationTime {
                Text(formatTime(timestamp))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var dataSection: some View {
        HStack(spacing: 20) {
            if let wind = metar.wind {
                Label {
                    Text("\(wind) kt")
                        .font(.subheadline)
                } icon: {
                    Image(systemName: "wind")
                        .foregroundStyle(.green)
                }
            }
            
            if let visibility = metar.visibility {
                Label {
                    Text(visibility)
                        .font(.subheadline)
                } icon: {
                    Image(systemName: "eye")
                        .foregroundStyle(.purple)
                }
            }
        }
    }
    
    private func rawTextSection(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
    }
    
    private func formatTime(_ timestamp: String) -> String {
        let parts = timestamp.split(separator: "T")
        if parts.count == 2 {
            let timePart = parts[1].prefix(5)
            return String(timePart)
        }
        return timestamp
    }
}

// MARK: - View Model
class WeatherViewModel: ObservableObject {
    @Published var metarData: [Metar] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let persistenceController = PersistenceManager.shared
    
    func fetchMetar(icao: String) {
        let trimmedIcao = icao.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        guard !trimmedIcao.isEmpty else {
            errorMessage = "Please enter a valid ICAO code"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "https://aviationweather.gov/api/data/metar?ids=\(trimmedIcao)&format=json") else {
            isLoading = false
            errorMessage = "Invalid URL"
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                   DispatchQueue.main.async {
                       guard let self = self else { return }
                       self.isLoading = false
                       self.handleResponse(data: data, response: response, error: error, icao: trimmedIcao)
                   }
               }.resume()
           }
    
    private func handleResponse(data: Data?, response: URLResponse?, error: Error?, icao: String) {
        if let error = error {
            errorMessage = "Network error: \(error.localizedDescription)"
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            errorMessage = "Invalid response from server"
            return
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            errorMessage = "Server error: \(httpResponse.statusCode)"
            return
        }
        
        guard let data = data else {
            errorMessage = "No data received"
            return
        }
        
        decodeMetarData(data, icao: icao)
    }
    
    private func decodeMetarData(_ data: Data, icao: String) {
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let response = try decoder.decode([Metar].self, from: data)
            
            if response.isEmpty {
                errorMessage = "No METAR data found for \(icao)"
            } else {
                metarData = response
                saveMetars(response)
            }
        } catch {
            errorMessage = "Failed to decode data: \(error.localizedDescription)"
            print("Decoding error: \(error)")
        }
    }
    
    func loadSavedMetars() {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<MetarEntity> = MetarEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \MetarEntity.observationTime, ascending: false)]
        
        do {
            let savedMetars = try context.fetch(fetchRequest)
            metarData = savedMetars.map { entity in
                Metar(
                    stationId: entity.stationId ?? "",
                    observationTime: entity.observationTime,
                    wind: entity.wind,
                    visibility: entity.visibility,
                    rawText: entity.rawText
                )
            }
        } catch {
            errorMessage = "Failed to load saved data: \(error.localizedDescription)"
        }
    }
    
    private func saveMetars(_ metars: [Metar]) {
        let context = persistenceController.container.viewContext
        
        for metar in metars {
            saveMetar(metar, in: context)
        }
    }
    
    private func saveMetar(_ metar: Metar, in context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<MetarEntity> = MetarEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "stationId == %@ AND observationTime == %@",
            metar.stationId,
            metar.observationTime ?? ""
        )
        
        do {
            let existingMetars = try context.fetch(fetchRequest)
            let metarEntity = existingMetars.first ?? MetarEntity(context: context)
            
            metarEntity.stationId = metar.stationId
            metarEntity.observationTime = metar.observationTime
            metarEntity.wind = metar.wind
            metarEntity.visibility = metar.visibility
            metarEntity.rawText = metar.rawText
            
            try context.save()
        } catch {
            errorMessage = "Error saving context: \(error.localizedDescription)"
        }
    }
}

// MARK: - Data Model
struct Metar: Codable, Identifiable {
    let id = UUID()
    let stationId: String
    let observationTime: String?
    let wind: String?
    let visibility: String?
    let rawText: String?
    
    enum CodingKeys: String, CodingKey {
        case stationId, observationTime, wind, visibility, rawText
    }
}

// MARK: - Persistence Manager
class PersistenceManager {
    static let shared = PersistenceManager()
    
    static var preview: PersistenceManager = {
        let result = PersistenceManager(inMemory: true)
        let viewContext = result.container.viewContext
        
        for _ in 0..<3 {
            let newMetar = MetarEntity(context: viewContext)
            newMetar.stationId = "LSZH"
            newMetar.wind = "27015KT"
            newMetar.visibility = "10SM"
            newMetar.observationTime = "2025-09-30T12:00:00Z"
            newMetar.rawText = "LSZH 301200Z 27015KT 9999 FEW040 18/12 Q1013"
        }
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()
    
    let container: NSPersistentContainer
    
    private init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "AviationWeatherApp")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceManager.preview.container.viewContext)
    }
}
