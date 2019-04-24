//
//  ViewController.swift
//  blue_test
//
//  Created by Yurii Topchii on 4/2/19.
//  Copyright © 2019 Yurii Topchii. All rights reserved.
//

import UIKit
import CoreBluetooth
import UserNotifications

class BtViewController: UIViewController {
    var centralManager: CBCentralManager!
    // service we search
    let scaleCBUUID = CBUUID(string: "0x181D")
    // our bt device instance
    var iqosPeripheral: CBPeripheral!

    @IBOutlet weak var btStatusLabel: UILabel!
    @IBOutlet weak var btDeviceName: UILabel!
    @IBOutlet weak var debugTextView: UITextView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionRestoreIdentifierKey: "restorationKey"])
        debugTextView.text = "Debug start"
        // #1.1 - Create "the notification's category value--its type."
        let debitOverdraftNotifCategory = UNNotificationCategory(identifier: "debitOverdraftNotification", actions: [], intentIdentifiers: [], options: [])
        // #1.2 - Register the notification type.
        UNUserNotificationCenter.current().setNotificationCategories([debitOverdraftNotifCategory])
    
        // Do any additional setup after loading the view.
    }
    
    func debugLog (log: String) {
        debugTextView.text = "\(debugTextView.text!) \n ----------------------- \n"

        debugTextView.text = "\(debugTextView.text!) \(log)"
    }
    
    func notify() {
        // find out what are the user's notification preferences
        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
            
            // we're only going to create and schedule a notification
            // if the user has kept notifications authorized for this app
            guard settings.authorizationStatus == .authorized else { return }
            
            // create the content and style for the local notification
            let content = UNMutableNotificationContent()
            
            // #2.1 - "Assign a value to this property that matches the identifier
            // property of one of the UNNotificationCategory objects you
            // previously registered with your app."
            content.categoryIdentifier = "charginNotification"
            
            // create the notification's content to be presented
            // to the user
            content.title = "Your iqos is charging"
            content.body = "If you see it then it's working"
            content.sound = UNNotificationSound.default
            
            // #2.2 - create a "trigger condition that causes a notification
            // to be delivered after the specified amount of time elapses";
            // deliver after 10 seconds
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            
            // create a "request to schedule a local notification, which
            // includes the content of the notification and the trigger conditions for delivery"
            let uuidString = UUID().uuidString
            let request = UNNotificationRequest(identifier: uuidString, content: content, trigger: trigger)
            
            // "Upon calling this method, the system begins tracking the
            // trigger conditions associated with your request. When the
            // trigger condition is met, the system delivers your notification."
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
            
            
        } // end getNotificationSettings
    }
    

}




// Delegate methods for centralManager
// Search device
extension BtViewController: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        switch central.state {
        case .unknown:
            self.btStatusLabel.text = "unknown"
            self.btStatusLabel.textColor = .red
        case .resetting:
             self.btStatusLabel.text = "resetting"
             self.btStatusLabel.textColor = .red
        case .unsupported:
             self.btStatusLabel.text = "unsupported"
             self.btStatusLabel.textColor = .red
        case .unauthorized:
             self.btStatusLabel.text = "unauthorized"
             self.btStatusLabel.textColor = .red
        case .poweredOff:
             self.btStatusLabel.text = "Off"
             self.btStatusLabel.textColor = .darkGray
        case .poweredOn:
             self.btStatusLabel.text = "On"
             self.btStatusLabel.textColor = .green
             centralManager.scanForPeripherals(withServices: [CBUUID(string: "DAEBB240-B041-11E4-9E45-0002A5D5C51B")])
            
        @unknown default:
            fatalError("cannot detect bt status")
        }
    }
    // Connect device
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        if let name = peripheral.name {
            if name == "My IQOS 2.4+" {
                debugLog(log: "found \(name)")
                self.btDeviceName.text = name
                iqosPeripheral = peripheral
                iqosPeripheral.delegate = self
                centralManager.stopScan()
                centralManager.connect(iqosPeripheral,
                                       options: [
                                        CBConnectPeripheralOptionNotifyOnConnectionKey:true,
                                        CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
                                        CBConnectPeripheralOptionNotifyOnNotificationKey: true])

            }
        }

    }
       // Discover services when connected
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        debugLog(log: "Connected")
        iqosPeripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        debugLog(log: "Disconnected")
        self.btDeviceName.text = "None"
    }
    
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        if dict.count>0 {
            debugLog(log: "willRestoreState")
        }
    }
    

}




// Delegate methods for CBPeripheralDelegate
extension BtViewController: CBPeripheralDelegate {
    // Services discovered
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        for service in services {
            debugLog(log:"SERVICE:")
            debugLog(log: service.uuid.uuidString)
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
   // Services discovered and subscribe
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.properties.contains(.read) {
                debugLog(log:"\(characteristic.uuid): properties contains .read")
                peripheral.readValue(for: characteristic)
            }
            if characteristic.properties.contains(.notify) {
                iqosPeripheral.setNotifyValue(true, for: characteristic)
                peripheral.readValue(for: characteristic)
                print(characteristic.service)
                debugLog(log: "\(characteristic.uuid): properties contains .notify")
            }
        }
    }
     // React to updates
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {

        peripheral.readValue(for: characteristic)

    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        guard let data = characteristic.value else {
            debugLog(log: "no value")
            return
        }
        
        if(characteristic.uuid.uuidString == "F8A54120-B041-11E4-9BE7-0002A5D5C51B") {
            debugLog(log: "charging")
            notify()
        } else {
            debugLog(log: String(data: data, encoding: String.Encoding.ascii)!);
        }
        

    }
    

}

