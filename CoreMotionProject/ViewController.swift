//
//  ViewController.swift
//  CoreMotionProject
//
//  Created by Firatondr on 14.11.2020.
//  Copyright © 2020 com.firatondr. All rights reserved.
//

import UIKit
import CoreMotion
import CoreLocation
import MapKit

class ViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {
    
    @IBOutlet var mapView: MKMapView!
    
    var previousState = "Durma"
    var previousFlag = "initialize"
    var previousDate = " "
    var previousTime = " "
    var firstLocation = CLLocation()
    var lastLocation =  CLLocation()
    var previousLocationSource = " "
    let activityManager = CMMotionActivityManager()
    let locationManager = CLLocationManager()
    var stopPoints: [CLLocation] = []
    var walkingRoute: [CLLocation] = []
    var drivingRoute: [CLLocation] = []
    var routeColor = UIColor.red
    
  
    override func viewDidLoad() {
        super.viewDidLoad()
        locationManager.requestAlwaysAuthorization()
        locationManager.delegate = self
/*
        processMapReducer(action: "Yürüme Deneme")
        processMapReducer(action: "Sürüş Deneme")
 */
        if CMMotionActivityManager.isActivityAvailable() {
            self.activityManager.startActivityUpdates(to: OperationQueue.main) { (data) in
                DispatchQueue.main.async {
                    if let activity = data {
                        if ( activity.stationary ) {
                            if ( self.checkIfStateShouldChange(state: "Durma", flag:"1") ) {
                                self.changeState(state: "Durma", lastFlag: "1")
                            }else if ( self.checkIfStateShouldChange(state: "Durma", flag: "0" ) ) {
                                return
                            }else if( self.shouldProgramInitialize(state: "Durma", flag: "initialize") ) {
                                self.previousFlag = "1"
                                self.formatAndSaveDate(x: activity.startDate)
                                self.initialize()
                            }
                            self.lastLocation = self.locationManager.location!
                            self.formatAndSaveDate(x: activity.startDate)
                            self.processMapReducer(action: "Durma")
                            
                        }else if ( activity.walking || activity.running  ) {
                            if ( self.checkIfStateShouldChange(state: "Yürüme", flag: "1" ) ) {
                                self.changeStateAndLocation(state: "Yürüme")
                                self.getHundredLocationForWalk()
                            
                            }
                            
                            let distance = self.getTimeAndReturnCalculatedDistance(date: activity.startDate)
                            if distance >= 100{
                                self.updateStatementAsMoving(state: "Yürüme")
                            }
                        }
                        else if ( activity.automotive )  {
                            if( self.checkIfStateShouldChange(state: "Sürüş", flag: "1") ) {
                                self.changeStateAndLocation(state: "Sürüş")
                                self.getBestLocationForDriveAndBegin()
                                
                            }
                            let distance = self.getTimeAndReturnCalculatedDistance(date: activity.startDate)
                            if distance >= 100  {
                                self.updateStatementAsMoving(state: "Sürüş")
                            }
                            
                        }
                    }
                }
            }
        }
    }
    
    //We could call this function (initialize) before the loops start and it would be more efficient. But if we call it with x: Date() before we initialize loops, a logical error between the first time and CoreMotion's times occurs. So we need to call init function inside our loop. In other words; we need to stick with CoreMotion's dates and time intervals.
    func initialize() {
        getBestLocationForDriveAndBegin()
        firstLocation = locationManager.location ?? CLLocation()
        lastLocation = firstLocation
        print("State","Durum","Tarih","Zaman","Enlem","Boylam","Konum Kaynak", separator: "        ")
        printState()
        stopPoints.append(firstLocation)
        
    }
    func processMapReducer (action: String) {
        var sourceLocation =  CLLocationCoordinate2D()
        var destinationLocation = CLLocationCoordinate2D()
        var directionReqType = MKDirectionsTransportType()
        
        if(action == "Durma"){
            sourceLocation = stopPoints[0].coordinate
            destinationLocation = stopPoints[0].coordinate
            directionReqType = .walking
            routeColor = .red
        }else if(action == "Yürüme"){
            directionReqType = .walking
            for index in 0..<walkingRoute.count-1 {
                sourceLocation = walkingRoute[index].coordinate
                destinationLocation = walkingRoute[index+1].coordinate
                routeColor = .orange
                processMap(sourceLocation: sourceLocation, destinationLocation: destinationLocation, requestType: directionReqType)
            }
        }else if (action == "Sürüş"){
            directionReqType = .automobile
            for index in 0..<drivingRoute.count-1 {
                sourceLocation = drivingRoute[index].coordinate
                destinationLocation = drivingRoute[index+1].coordinate
                routeColor = .green
                processMap(sourceLocation: sourceLocation, destinationLocation: destinationLocation, requestType: directionReqType)
            }
        }else if (action == "Yürüme Deneme" ) {
            let src1 = CLLocationCoordinate2D(latitude: 41.137451171875 , longitude: 30.05353535353555)
            let dl1 = CLLocationCoordinate2D(latitude: 41.138999999999, longitude: 29.041490698844665)
            var rt1 = MKDirectionsTransportType()
            rt1 = .walking
            routeColor = UIColor.blue
            processMap(sourceLocation: src1, destinationLocation: dl1, requestType: rt1)
        }else if (action == "Sürüş Deneme" ) {
         let src = CLLocationCoordinate2D(latitude: 41.137451171875 , longitude: 29.041490698844665)
         let dl = CLLocationCoordinate2D(latitude: 41.138999999999, longitude: 29.041490698844665)
         var rt = MKDirectionsTransportType()
         rt = .automobile

        routeColor = UIColor.red
        processMap(sourceLocation: src, destinationLocation: dl, requestType: rt)
    }
    }
    
    func processMap (sourceLocation: CLLocationCoordinate2D, destinationLocation: CLLocationCoordinate2D , requestType: MKDirectionsTransportType ) {
 
        let sourcePlaceMark = MKPlacemark(coordinate: sourceLocation)
        let destinationPlaceMark = MKPlacemark(coordinate: destinationLocation)
        let directionRequest = MKDirections.Request()
        directionRequest.source = MKMapItem(placemark: sourcePlaceMark)
        directionRequest.destination = MKMapItem(placemark: destinationPlaceMark)
        directionRequest.transportType = requestType
        
        
        let directions = MKDirections(request: directionRequest)
        directions.calculate { (response, error) in
            guard let directionResonse = response else {
                if let error = error {
                    print("\(error.localizedDescription)")
                }
                return
            }
            let route = directionResonse.routes[0]
            self.mapView.addOverlay(route.polyline, level: .aboveRoads)
            
            let rect = route.polyline.boundingMapRect
            self.mapView.setRegion(MKCoordinateRegion(rect), animated: true)
        }
        mapView.delegate = self
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(overlay: overlay)
        renderer.strokeColor = routeColor
        renderer.lineWidth = 10.0
        return renderer
    }
    
  
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func shouldProgramInitialize (state: String, flag: String) -> Bool {
        return previousState == state && previousFlag == flag
    }
    
    func checkIfStateShouldChange (state: String, flag: String) -> Bool {
        return previousState != state && previousFlag == flag && previousFlag != "initialize"
    }
    
    func updateStatementAsMoving(state: String) {
        previousState = state
        previousFlag = "1"
        firstLocation = locationManager.location!
        printState()
        
        if ( state == "Yürüme" ){
            walkingRoute.append(firstLocation)
            walkingRoute.append(lastLocation)
            processMapReducer(action: "Yürüme")
            return
        }
        drivingRoute.append(firstLocation)
        drivingRoute.append(lastLocation)
        processMapReducer(action: "Sürüş")
        
    }
    func changeState (state: String , lastFlag: String) {
        previousFlag = "0"
        printState()
        previousState = state
        previousFlag = lastFlag
        printState()
    }
    func changeStateAndLocation (state: String) {
        previousFlag = "0"
        firstLocation = locationManager.location!
        printState()
        previousState = state
    }

    func getTimeAndReturnCalculatedDistance (date: Date) -> Double {
        formatAndSaveDate(x: date)
        lastLocation = locationManager.location!
        return firstLocation.distance(from: lastLocation)
    }
    
    func printState() {
        print( previousFlag,
               previousState,
               previousDate,
               previousTime,
               lastLocation.coordinate.latitude,
               lastLocation.coordinate.longitude, separator: "      " )
    }
    
    func getBestLocationForDriveAndBegin () {
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func getHundredLocationForWalk () {
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
    
    func formatAndSaveDate (x: Date) {
        let requiredDateFormat = DateFormatter()
        requiredDateFormat.dateFormat = "dd.MM.yyyy HH:mm:ss"
        
        let date: String? = requiredDateFormat.string(from: x)
        
        let dateArray = date?.components(separatedBy: " ")
        previousDate = dateArray?[0] ?? " "
        previousTime = dateArray?[1] ?? " "
    }
}

