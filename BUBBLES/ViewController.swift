//
//  ViewController.swift
//  BUBBLES
//
//  Created by Ari Troper on 11/4/18.
//  Copyright © 2018 Ari Troper. All rights reserved.
//

import UIKit
import UIColor_Hex_Swift
import Firebase
import AudioToolbox

class ViewController: UIViewController, UITextFieldDelegate
{
    @IBOutlet weak var instructions: UILabel!
    @IBOutlet weak var circle: UIView!
    @IBOutlet weak var idea: UITextField!
    @IBOutlet weak var close: UIButton!
    @IBOutlet weak var bubbleCount: UILabel!
    
    var bubbleExists: Bool!
    var ideaString: String! //idea to post
    var flingMessage: String! //message to display on fling
    var timer = Timer()
    var ideaListIndex = 0
    var ideaList = ["Max", "and", "Ari", "are", "cofounders", "of", "bubbles."] //idea from cloud
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.becomeFirstResponder()
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        ideaString = ""
        flingMessage = "TO THE CLOUD!"
        bubbleExists = false
        
        getBubbleCount()
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(tap(sender:)))
        self.view.addGestureRecognizer(tap)
        
        let swipeUp = UISwipeGestureRecognizer(target: self, action: #selector(moveUp(sender:)))
        swipeUp.direction = .up
        self.view.addGestureRecognizer(swipeUp)
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            if self.view.frame.origin.y == 0{
                self.view.frame.origin.y -= keyboardSize.height / 2
            }
        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        if self.view.frame.origin.y != 0
        {
            self.view.frame.origin.y = 0
        }
    }
    
    /**
     Checks textfield everytime changed.
     **/
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let char = string.cString(using: String.Encoding.utf8)!
        let isSpace = strcmp(char, "\\b")
        
        //if space, reset textfield and add text to the message
        if isSpace == -60
        {
            ideaString.append(textField.text!)
            textField.text = ""
        }
        
        return true
    }
    
    @IBAction func close(_ sender: Any)
    {
        shrink()
    }
    
    func canBecomeFirstResponder() -> Bool
    {
        return true
    }
    
    // Enable detection of shake motion.
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?)
    {
        /**
         On shake.
        **/
        if motion == .motionShake
        {
            AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
            if !bubbleExists
            {
                Database.database().reference().child("ideas").observeSingleEvent(of: .value, with: { snapshot in
                    if let snapshot = snapshot.children.allObjects as? [DataSnapshot]
                    {
                        if snapshot.count != 0
                        {
                            let rand = Int.random(in: 0...snapshot.count-1)
                            self.ideaList = (snapshot[rand].value as! String).split(separator: " ").map(String.init)
                            
                            Database.database().reference().child("ideas").child(snapshot[rand].key).removeValue()
                            
                            self.circle.alpha = 1
                            self.circle.addSubview(self.makeCircle(color: UIColor("#74b9ff")))
                            self.idea.isUserInteractionEnabled = false
                            self.idea.borderStyle = .none
                            self.idea.text = "Loading..."
                            self.flingMessage = "CYA!"
                            self.grow(fromTap: false)
                        }
                        else
                        {
                            self.showToast(message: "No more bubbles!")
                        }
                        
                    }
                })
            }
        }
    }
    
    /**
     Gets number of bubbles in cloud and updates label.
    **/
    func getBubbleCount()
    {
        Database.database().reference().child("ideas").observeSingleEvent(of: .value, with: { snapshot in
            self.bubbleCount.text = "Number of bubbles: " + String(snapshot.childrenCount)
        })
    }
    
    /**
     Grows circle subview, becomes editable on completion.
    **/
    func grow(fromTap: Bool)
    {
        self.bubbleExists = true
        UIView.animate(withDuration: 1, animations: {
            for subview in self.circle.subviews{
                self.idea.alpha = 1
                subview.transform = subview.transform.scaledBy(x: 100, y: 100)
            }
        }, completion: { finished in
            self.instructions.alpha = 0
            if fromTap
            {
                self.idea.becomeFirstResponder()
            }
            else
            {
                self.timer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(self.animateLabel), userInfo: nil, repeats: true)
            }
        })
    }
    
    @objc func animateLabel()
    {
        idea.text = ideaList[ideaListIndex % ideaList.count]
        ideaListIndex += 1
    }
    
    func shrink()
    {
        idea.isUserInteractionEnabled = false
        UIView.animate(withDuration: 1, animations: {
            for subview in self.circle.subviews{
                self.idea.alpha = 0
                subview.transform = subview.transform.scaledBy(x: 0.01, y: 0.01)
            }
        }, completion: { finished in
            self.reset()
        })
    }
    
    /**
     Fligns circle subview up, calls reset on completion.
    **/
    func fling()
    {
        self.idea.resignFirstResponder()
        getBubbleCount()
        close.alpha = 0
        
        idea.text = flingMessage
        idea.font = UIFont(name: "Avenir-Heavy", size: 30)
        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
        
        UIView.animate(withDuration: 1, animations: {
            for subview in self.circle.subviews{
                self.idea.isUserInteractionEnabled = false
                self.idea.alpha = 0
                subview.transform = subview.transform.scaledBy(x: 50, y: 50)
                subview.backgroundColor = UIColor.white
            }
        }, completion: { finished in
            self.reset()
        })
    }
    
    /**
     Creates a circle of color UIColor, and returns.
    **/
    func makeCircle(color: UIColor) -> UIView
    {
        let circleLayer = UIView(frame: CGRect(x: circle.frame.size.width / 2, y: circle.frame.size.height / 2, width: 3, height: 3))
        circleLayer.center = CGPoint(x: circle.frame.size.width / 2, y: circle.frame.size.height / 2)
        circleLayer.layer.cornerRadius = 1.5
        circleLayer.backgroundColor = color
        circleLayer.clipsToBounds = true
        
        return circleLayer
    }
    
    /**
     Resets views.
    **/
    func reset()
    {
        //fades instructions back in
        self.view.endEditing(true)
        UIView.animate(withDuration: 0.5, animations: {
            self.instructions.alpha = 1
        })
        
        bubbleExists = false
        ideaString = ""
        ideaListIndex = 0
        idea.resignFirstResponder()
        idea.text = ""
        idea.isUserInteractionEnabled = true
        idea.font = UIFont(name: "Avenir-Book", size: 17)
        close.alpha = 0
        circle.alpha = 0
        circle.subviews.forEach({ $0.removeFromSuperview() })
    }
    
    /**
     On gesture slide up.
    **/
    @objc func moveUp(sender: UISwipeGestureRecognizer)
    {
        ideaString.append(idea.text!)
        
        //check that idea exists
        if(ideaString != "")
        {
            if idea.isUserInteractionEnabled
            {
                Database.database().reference().child("ideas").child(Date.init().description).setValue(ideaString)
            }
            timer.invalidate()
            fling()
        }
    }
    
    /**
     On gesture tap.
    **/
    @objc func tap(sender: UITapGestureRecognizer)
    {
        if !bubbleExists
        {
            close.alpha = 1
            flingMessage = "TO THE CLOUD!"
            circle.alpha = 1
            circle.addSubview(makeCircle(color: UIColor("#74b9ff")))
            grow(fromTap: true)
        }
    }
}

extension UIViewController {
    
    func showToast(message : String) {
        
        let toastLabel = UILabel(frame: CGRect(x: self.view.frame.size.width/2 - 75, y: self.view.frame.size.height-100, width: 150, height: 35))
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        toastLabel.textColor = UIColor.white
        toastLabel.textAlignment = .center;
        toastLabel.font = UIFont(name: "Montserrat-Light", size: 7)
        toastLabel.text = message
        toastLabel.alpha = 1.0
        toastLabel.layer.cornerRadius = 10;
        toastLabel.clipsToBounds  =  true
        self.view.addSubview(toastLabel)
        
        UIView.animate(withDuration: 4.0, delay: 0.1, options: .curveEaseOut, animations: {
            toastLabel.alpha = 0.0
        }, completion: {(isCompleted) in
            toastLabel.removeFromSuperview()
        })
    }
}
