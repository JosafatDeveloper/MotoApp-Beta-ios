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

class HomeViewController: UIViewController {
  var managedObjectContext: NSManagedObjectContext?
  var nombreUser:String!
  override func viewDidLoad() {
    super.viewDidLoad()
    let fetchRequest = NSFetchRequest(entityName: "User")
    let sortDescriptor = NSSortDescriptor(key: "username", ascending: false)
    fetchRequest.sortDescriptors = [sortDescriptor]
    let users = (try! managedObjectContext!.executeFetchRequest(fetchRequest)) as! [User]
    print(users)
    if(users.count == 0){
      crearusuario()
    }
  }
  
  func crearusuario(){
    //1. Create the alert controller.
    let alert = UIAlertController(title: "Alias", message: "Escribe un Alias", preferredStyle: .Alert)
    //2. Add the text field. You can configure it however you need.
    alert.addTextFieldWithConfigurationHandler({ (textField) -> Void in
      textField.placeholder = "Flamas"
    })
    //3. Grab the value from the text field, and print it when the user clicks OK.
    alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: { (action) -> Void in
      let textField = alert.textFields![0] as UITextField
      self.nombreUser = textField.text
      // 1
      let savedUser = NSEntityDescription.insertNewObjectForEntityForName("User",
        inManagedObjectContext: self.managedObjectContext!) as! User
      savedUser.username = textField.text!
      
      // 3
      var error: NSError?
      let success: Bool
      do {
        try self.managedObjectContext!.save()
        success = true
      } catch let error1 as NSError {
        error = error1
        success = false
      }
      if !success {
        print("New user!:\(self.nombreUser)")
      }
    }))
    // 4. Present the alert.
    self.presentViewController(alert, animated: true, completion: nil)
  }

  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    if segue.destinationViewController.isKindOfClass(NewRunViewController) {
      if let newRunViewController = segue.destinationViewController as? NewRunViewController {
        newRunViewController.managedObjectContext = managedObjectContext
      }
    }
    else if segue.destinationViewController.isKindOfClass(BadgesTableViewController) {
      let fetchRequest = NSFetchRequest(entityName: "Run")

      let sortDescriptor = NSSortDescriptor(key: "timestamp", ascending: false)
      fetchRequest.sortDescriptors = [sortDescriptor]

      let runs = (try! managedObjectContext!.executeFetchRequest(fetchRequest)) as! [Run]

      let badgesTableViewController = segue.destinationViewController as! BadgesTableViewController
      badgesTableViewController.badgeEarnStatusesArray = BadgeController.sharedController.badgeEarnStatusesForRuns(runs)
    }

  }
}