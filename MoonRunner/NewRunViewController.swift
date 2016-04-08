/*
* Copyright (c) 2015 Razeware LLC
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
* THE SOFTWARE.
*/

import UIKit
import CoreData
import CoreLocation
import HealthKit
import MapKit
import AudioToolbox

let DetailSegueName = "RunDetails"

class NewRunViewController: UIViewController {
  var managedObjectContext: NSManagedObjectContext?

  var run: Run!

  var upcomingBadge : Badge?
  
  var updateTimer: NSTimer?
  var backgroundTask: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid

  @IBOutlet weak var promptLabel: UILabel!
  @IBOutlet weak var timeLabel: UILabel!
  @IBOutlet weak var distanceLabel: UILabel!
  @IBOutlet weak var paceLabel: UILabel!
  @IBOutlet weak var startButton: UIButton!
  @IBOutlet weak var stopButton: UIButton!
  @IBOutlet weak var viajeNombre: UILabel!
  var nombreViajeString:String!
  var users:[User]!

  @IBOutlet weak var mapView: MKMapView!

  var seconds = 0.0
  var distance = 0.0

  lazy var locationManager: CLLocationManager = {
    var _locationManager = CLLocationManager()
    _locationManager.delegate = self
    _locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
    _locationManager.activityType = CLActivityType.AutomotiveNavigation
    _locationManager.distanceFilter =  kCLDistanceFilterNone
  

    // Movement threshold for new events
    _locationManager.distanceFilter = 10.0
    return _locationManager
    }()

  lazy var locations = [CLLocation]()
  lazy var timer = NSTimer()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(NewRunViewController.reinstateBackgroundTask), name: UIApplicationDidBecomeActiveNotification, object: nil)
    //orderTask()
    print("GPS Task")
    let fetchRequest = NSFetchRequest(entityName: "User")
    let sortDescriptor = NSSortDescriptor(key: "username", ascending: false)
    fetchRequest.sortDescriptors = [sortDescriptor]
    users = (try! managedObjectContext!.executeFetchRequest(fetchRequest)) as! [User]
    print(users)
    
  }
  
  deinit {
    NSNotificationCenter.defaultCenter().removeObserver(self)
  }
  
  func reinstateBackgroundTask() {
    if updateTimer != nil && (backgroundTask == UIBackgroundTaskInvalid) {
      registerBackgroundTask()
    }
  }
  
  func registerBackgroundTask() {
    backgroundTask = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler {
      [unowned self] in
      self.endBackgroundTask()
    }
    assert(backgroundTask != UIBackgroundTaskInvalid)
  }
  
  func endBackgroundTask() {
    NSLog("Background task ended.")
    UIApplication.sharedApplication().endBackgroundTask(backgroundTask)
    backgroundTask = UIBackgroundTaskInvalid
  }
  
  func activityback(){
    
    switch UIApplication.sharedApplication().applicationState {
    case .Active:
      // Active app
      break
    case .Background:
      NSLog("App is backgrounded. Next number ")
      NSLog("Background time remaining = %.1f seconds", UIApplication.sharedApplication().backgroundTimeRemaining)
    case .Inactive:
      break
    }
  }
  func orderTask(){
    updateTimer = NSTimer.scheduledTimerWithTimeInterval(0.5, target: self,
                                                         selector: #selector(NewRunViewController.activityback), userInfo: nil, repeats: true)
    registerBackgroundTask()
  }
  // End task

  override func viewWillAppear(animated: Bool) {
    super.viewWillAppear(animated)

    startButton.hidden = false
    promptLabel.hidden = false

    timeLabel.hidden = true
    distanceLabel.hidden = true
    paceLabel.hidden = true
    stopButton.hidden = true

    locationManager.requestAlwaysAuthorization()

    mapView.hidden = true
  }

  override func viewWillDisappear(animated: Bool) {
    super.viewWillDisappear(animated)
    timer.invalidate()
  }

  func eachSecond(timer: NSTimer) {
    seconds += 1
    let secondsQuantity = HKQuantity(unit: HKUnit.secondUnit(), doubleValue: seconds)
    timeLabel.text = "Tiempo: " + secondsQuantity.description
    let distanceQuantity = HKQuantity(unit: HKUnit.meterUnit(), doubleValue: distance)
    distanceLabel.text = "Distancia: " + distanceQuantity.description

    let paceUnit = HKUnit.secondUnit().unitDividedByUnit(HKUnit.meterUnit())
    let paceQuantity = HKQuantity(unit: paceUnit, doubleValue: seconds / distance)
    paceLabel.text = "Velocidad: " + paceQuantity.description

    
  }

  func startLocationUpdates() {
    // Here, the location manager will be lazily instantiated
    locationManager.startUpdatingLocation()
  }

  func saveRun() {
    print("Proceso Save")
    // 1
    let savedRun = NSEntityDescription.insertNewObjectForEntityForName("Run",
      inManagedObjectContext: managedObjectContext!) as! Run
    savedRun.distance = distance
    savedRun.duration = seconds
    savedRun.timestamp = NSDate()

    // 2
    var savedLocations = [Location]()
    for location in locations {
      let savedLocation = NSEntityDescription.insertNewObjectForEntityForName("Location",
        inManagedObjectContext: managedObjectContext!) as! Location
      savedLocation.timestamp = location.timestamp
      savedLocation.latitude = location.coordinate.latitude
      savedLocation.longitude = location.coordinate.longitude
      savedLocations.append(savedLocation)
    }

    savedRun.locations = NSOrderedSet(array: savedLocations)
    run = savedRun

    // 3
    var error: NSError?
    let success: Bool
    do {
      try managedObjectContext!.save()
        updateViaje(run)
      viajeNombre.enabled = true

      success = true
    } catch let error1 as NSError {
      error = error1
      success = false
    }
    if !success {
      print("Could not save the run!")
    }
  }
    
  func unploadData(distance_run:NSNumber, duration_run:NSNumber, timestamp_run:NSDate, locatesave:CLLocation){
        let myUrl = NSURL(string: "http://squashmex.com.mx/api_motoapp/DeveloperSaveSatusMovil.php");let request = NSMutableURLRequest(URL:myUrl!);
        
        request.HTTPMethod = "POST";
        let string_run = "r={\"d\":\(distance_run),\"u\":\(duration_run),\"s\":\"\(timestamp_run)\",\"id\":\"\(UIDevice.currentDevice().identifierForVendor!.UUIDString)\",\"v\":\"\(nombreViajeString)\",\"n\":\"\(users[0].username)\"}"
        print(string_run)
        var stringlocate = "l={\"l\": ["
          stringlocate += "{"
          stringlocate += "\"la\":\(locatesave.coordinate.latitude),"
          stringlocate += "\"lo\":\(locatesave.coordinate.longitude),"
          stringlocate += "\"s\":\"\(locatesave.timestamp)\""
          stringlocate += "}"
        stringlocate += "]}"
        //print(stringlocate)
        
        // Compose a query string
        //print(locatesave)
        let postString = "\(string_run)&\(stringlocate)";
        
        request.HTTPBody = postString.dataUsingEncoding(NSUTF8StringEncoding);
        
        let task = NSURLSession.sharedSession().dataTaskWithRequest(request) {
          data, response, error in
          if error != nil
          {
            print("error=\(error)")
            return
          }
          // You can print out response object
          //print("response = \(response)")
          
          // Print out response body
          let responseString = NSString(data: data!, encoding: NSUTF8StringEncoding)
          //print("responseString = \(responseString)")
          
          //Let’s convert response sent from a server side script to a NSDictionary object:
          
          //var err: NSError!
          do{
            let myJSON = try NSJSONSerialization.JSONObjectWithData(data!, options: .MutableLeaves) as? NSDictionary
            if let parseJSON = myJSON {
              // Now we can access value of First Name by its key
              //let firstNameValue = parseJSON["firstName"] as? String
              //print("firstNameValue: \(firstNameValue)")
            }
          }catch _{
            print("Error")
          }
          
          
          
          
        }
        
        task.resume()
    
    }

  func updateViaje(runsave:Run){
    
      let myUrl = NSURL(string: "http://squashmex.com.mx/api_motoapp/DeveloperSaveSatusMovil.php");let request = NSMutableURLRequest(URL:myUrl!);
      request.HTTPMethod = "POST";
      let string_run = "r={\"d\":\(runsave.distance),\"u\":\(runsave.duration),\"s\":\"\(runsave.timestamp)\",\"id\":\"\(UIDevice.currentDevice().identifierForVendor!.UUIDString)\",\"v\":\"\(viajeNombre.text)\",\"n\":\"\(users[0].username)\"}"
    
      //print(stringlocate)
      
      // Compose a query string
      //print(locatesave)
      let postString = "\(string_run)";
      
      request.HTTPBody = postString.dataUsingEncoding(NSUTF8StringEncoding);
      
      let task = NSURLSession.sharedSession().dataTaskWithRequest(request) {
        data, response, error in
        if error != nil
        {
          print("error=\(error)")
          return
        }
        // You can print out response object
        print("response = \(response)")
        
        // Print out response body
        let responseString = NSString(data: data!, encoding: NSUTF8StringEncoding)
        print("responseString = \(responseString)")
        
        //Let’s convert response sent from a server side script to a NSDictionary object:
        
        //var err: NSError!
        do{
          let myJSON = try NSJSONSerialization.JSONObjectWithData(data!, options: .MutableLeaves) as? NSDictionary
          if let parseJSON = myJSON {
            // Now we can access value of First Name by its key
            //let firstNameValue = parseJSON["firstName"] as? String
            //print("firstNameValue: \(firstNameValue)")
          }
        }catch _{
          print("Error")
        }
        
        
        
        
      }
      
      task.resume()
  }
  @IBAction func startPressed(sender: AnyObject) {
    if(viajeNombre.enabled){
      //1. Create the alert controller.
      let alert = UIAlertController(title: "Viaje", message: "Escriba el nombre de su viaje", preferredStyle: .Alert)
      //2. Add the text field. You can configure it however you need.
      alert.addTextFieldWithConfigurationHandler({ (textField) -> Void in
        textField.text = "Agrege su viaje"
      })
      //3. Grab the value from the text field, and print it when the user clicks OK.
      alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: { (action) -> Void in
        let textField = alert.textFields![0] as UITextField
        let randomNumber = arc4random()
        let viaje:NSString = textField.text! as NSString
        self.nombreViajeString = "v-\(viaje)-\(randomNumber)"
        self.viajeNombre.enabled = false
      }))
      // 4. Present the alert.
      self.presentViewController(alert, animated: true, completion: nil)
    }else{
      startButton.hidden = true
      promptLabel.hidden = true
      
      timeLabel.hidden = false
      distanceLabel.hidden = false
      paceLabel.hidden = false
      stopButton.hidden = false
      
      seconds = 0.0
      distance = 0.0
      locations.removeAll(keepCapacity: false)
      timer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: #selector(NewRunViewController.eachSecond(_:)), userInfo: nil, repeats: true)
      registerBackgroundTask()
      startLocationUpdates()
      
      mapView.hidden = false
    }
  }

  @IBAction func stopPressed(sender: AnyObject) {
    let actionSheet = UIActionSheet(title: "Run Stopped", delegate: self, cancelButtonTitle: "Cancel", destructiveButtonTitle: nil, otherButtonTitles: "Save", "Discard")
    actionSheet.actionSheetStyle = .Default
    actionSheet.showInView(view)
  }


  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    if let detailViewController = segue.destinationViewController as? DetailViewController {
      detailViewController.run = run
    }
  }
}

// MARK: - MKMapViewDelegate
extension NewRunViewController: MKMapViewDelegate {
  func mapView(mapView: MKMapView, rendererForOverlay overlay: MKOverlay) -> MKOverlayRenderer! {
    if !overlay.isKindOfClass(MKPolyline) {
      return nil
    }

    let polyline = overlay as! MKPolyline
    let renderer = MKPolylineRenderer(polyline: polyline)
    renderer.strokeColor = UIColor.blueColor()
    renderer.lineWidth = 3
    return renderer
  }
}

// MARK: - CLLocationManagerDelegate
extension NewRunViewController: CLLocationManagerDelegate {
  func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    for location in locations {
      let howRecent = location.timestamp.timeIntervalSinceNow

      if abs(howRecent) < 10 && location.horizontalAccuracy < 20 {
        if self.locations.count > 0 {
          distance += location.distanceFromLocation(self.locations.last!)
          
          var coords = [CLLocationCoordinate2D]()
          coords.append(self.locations.last!.coordinate)
          coords.append(location.coordinate)
          
          let region = MKCoordinateRegionMakeWithDistance(location.coordinate, 500, 500)
          mapView.setRegion(region, animated: true)
          
          mapView.addOverlay(MKPolyline(coordinates: &coords, count: coords.count))
        }
        //update distance
        switch UIApplication.sharedApplication().applicationState {
        case .Active:
          // Active app
          break
        case .Background: break
          //NSLog("App is backgrounded. Next number ")
          //NSLog("Background time remaining = %.1f seconds", UIApplication.sharedApplication().backgroundTimeRemaining)
        case .Inactive:
          break
        }
        // Load Back !!!!
        
        //save location
        self.locations.append(location)
        
        
        
        
        let savedLocations:CLLocation = self.locations.last!
        self.unploadData(distance, duration_run: seconds, timestamp_run: NSDate(), locatesave: savedLocations)
        print("New Location")
      }
    }
  }
}

// MARK: - UIActionSheetDelegate
extension NewRunViewController: UIActionSheetDelegate {
  func actionSheet(actionSheet: UIActionSheet, clickedButtonAtIndex buttonIndex: Int) {
    //save
    if buttonIndex == 1 {
      saveRun()
      performSegueWithIdentifier(DetailSegueName, sender: nil)
    }
      //discard
    else if buttonIndex == 2 {
      navigationController?.popToRootViewControllerAnimated(true)
    }
  }
}
