//
//  CommentsViewController.swift
//  Hackers2
//
//  Created by Weiran Zhang on 07/06/2014.
//  Copyright (c) 2014 Glass Umbrella. All rights reserved.
//

import Foundation
import UIKit
import SafariServices
import libHN
import DZNEmptyDataSet

class CommentsViewController : UIViewController, UITableViewDelegate, UITableViewDataSource, CommentDelegate, SFSafariViewControllerDelegate, PostTitleViewDelegate, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate {
    var post: HNPost?
    
    var comments: [CommentModel]? {
        didSet { commentsController.comments = comments! }
    }
    
    let commentsController = CommentsController()
    
    @IBOutlet var tableView: UITableView!
    
    @IBOutlet weak var postTitleView: PostTitleView!
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var thumbnailImageViewWidthConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupPostTitleView()
        
        tableView.estimatedRowHeight = 44.0
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.emptyDataSetSource = self
        tableView.emptyDataSetDelegate = self
        
        Theme.setNavigationBarBackground(navigationController?.navigationBar)
        NotificationCenter.default.addObserver(self, selector: #selector(CommentsViewController.viewDidRotate), name: .UIDeviceOrientationDidChange, object: nil)
        
        loadComments()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.shared.statusBarStyle = .lightContent
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if let headerView = tableView.tableHeaderView {
            let height = headerView.systemLayoutSizeFitting(UILayoutFittingCompressedSize).height
            var headerFrame = headerView.frame
            
            // If we don't have this check, viewDidLayoutSubviews() will get called
            // repeatedly, causing the app to hang.
            if height != headerFrame.size.height {
                headerFrame.size.height = height
                headerView.frame = headerFrame
                tableView.tableHeaderView = headerView
            }
        }
    }
    
    @objc func viewDidRotate() {
        Theme.setNavigationBarBackground(navigationController?.navigationBar)
    }
    
    func loadComments() {
        HNManager.shared().loadComments(from: post) { comments in
            if let downcastedArray = comments as? [HNComment] {
                let mappedComments = downcastedArray.map { CommentModel(source: $0) }
                self.comments = mappedComments
            } else {
                self.comments = [CommentModel]()
            }
            self.tableView.reloadData()
        }
    }
    
    func setupPostTitleView() {
        postTitleView.post = post
        postTitleView.delegate = self
        
        thumbnailImageViewWidthConstraint.constant = 0
        thumbnailImageView.layer.cornerRadius = 7
        thumbnailImageView.layer.masksToBounds = true
        
        if let imageUrlString = post?.urlString, let imageUrl = URL(string: imageUrlString) {
            ThumbnailFetcher.getThumbnail(url: imageUrl) { [weak self] image in
                DispatchQueue.main.async {
                    self?.thumbnailImageView.image = image
                    self?.thumbnailImageViewWidthConstraint.constant = 80                    
                }
            }
        }
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return commentsController.visibleComments.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Comments"
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let comment = commentsController.visibleComments[indexPath.row]
        assert(comment.visibility != .hidden, "Cell cannot be hidden and in the array of visible cells")
        let cellIdentifier = comment.visibility == CommentVisibilityType.visible ? "OpenCommentCell" : "ClosedCommentCell"

        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! CommentTableViewCell
        
        cell.comment = comment
        cell.delegate = self
        
        return cell
    }
    
    // MARK: - DZNEmptyDataSet
    
    func title(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
        let attributes = [NSAttributedStringKey.font: UIFont.systemFont(ofSize: 15.0)]
        return comments == nil ? NSAttributedString(string: "Loading comments", attributes: attributes) : NSAttributedString(string: "No comments", attributes: attributes)
    }
    
    // MARK: - Cell Actions
    
    func commentTapped(_ sender: UITableViewCell) {
        let indexPath = tableView.indexPath(for: sender)
        toggleCellVisibilityForCell(indexPath)
    }
    
    func linkTapped(_ URL: Foundation.URL, sender: UITextView) {
        let safariViewController = SFSafariViewController(url: URL)
        self.present(safariViewController, animated: true, completion: nil)
        UIApplication.shared.statusBarStyle = .default
    }
    
    func toggleCellVisibilityForCell(_ indexPath: IndexPath!) {
        let comment = commentsController.visibleComments[indexPath.row]
        let cellRectInTableView = tableView.rectForRow(at: indexPath)
        let cellRectInSuperview = tableView.convert(cellRectInTableView, to: tableView.superview)

        let (modifiedIndexPaths, visibility) = commentsController.toggleCommentChildrenVisibility(comment)
                
        tableView.beginUpdates()
        tableView.reloadRows(at: [indexPath], with: .fade)
        if visibility == CommentVisibilityType.hidden {
            tableView.deleteRows(at: modifiedIndexPaths, with: .middle)
        } else {
            tableView.insertRows(at: modifiedIndexPaths, with: UITableViewRowAnimation.middle)
        }
        tableView.endUpdates()
        
        if cellRectInSuperview.origin.y < 0 {
            tableView.scrollToRow(at: indexPath, at: .top, animated: true)
        }
    }
    
    // MARK: - PostTitleViewDelegate
    
    func didPressLinkButton(_ post: HNPost) {
        let safariViewController = SFSafariViewController(url: URL(string: post.urlString)!)
        self.present(safariViewController, animated: true, completion: nil)
        UIApplication.shared.statusBarStyle = .default
    }
    
    @IBAction func didTapThumbnail(_ sender: Any) {
        didPressLinkButton(post!)
    }
    
    @IBAction func shareTapped(_ sender: AnyObject) {
        let activityViewController = UIActivityViewController(activityItems: [post!.title, URL(string: post!.urlString)!], applicationActivities: nil)
        activityViewController.popoverPresentationController?.barButtonItem = sender as? UIBarButtonItem
        present(activityViewController, animated: true, completion: nil)
    }
}
