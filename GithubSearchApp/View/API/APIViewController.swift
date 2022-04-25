//
//  APIViewController.swift
//  GithubSearchApp
//
//  Created by 박근보 on 2022/04/22.
//

import UIKit
import RxSwift
import RxCocoa
import RxDataSources
import Toast

class APIViewController: BaseViewController {

    private lazy var input = APIViewModel.Input(
        requestUserListEvent: requestUserListEvent.asSignal(),
        requestNextPageListEvent: requestNextPageListEvent.asSignal(),
        apiTabPressEvent: apiTabPressEvent.asSignal(),
        searchFavoriteUserListEvent: searchFavoriteUserListEvent.asSignal(),
        localTabPressEvent: localTabPressEvent.asSignal(),
        pressFavoriteButtonEvent: pressFavoriteButtonEvent.asSignal()
    )
    private lazy var output = viewModel.transform(input: input)

    private let requestUserListEvent = PublishRelay<String>()
    private let requestNextPageListEvent = PublishRelay<String>()
    private let apiTabPressEvent = PublishRelay<Void>()
    private let searchFavoriteUserListEvent = PublishRelay<String>()
    private let localTabPressEvent = PublishRelay<Void>()
    private let pressFavoriteButtonEvent = PublishRelay<Int>()

    private let mainView = APIView()
    private var viewModel = APIViewModel()
    private let disposeBag = DisposeBag()

    override func loadView() {
        self.view = mainView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func setViewConfig() {
        super.setViewConfig()

        mainView.searchBar.delegate = self
        mainView.searchBar.searchTextField.delegate = self

        mainView.searchTableView.register(SearchTableViewCell.self, forCellReuseIdentifier: SearchTableViewCell.identifier)
        mainView.searchTableView.keyboardDismissMode = .onDrag
        mainView.searchTableView.rowHeight = 100
    }

    override func bind() {

        output.didLoadUserList
            .drive(mainView.searchTableView.rx.items(cellIdentifier: SearchTableViewCell.identifier, cellType: SearchTableViewCell.self)) { (row, element, cell) in
                cell.cellConfig(searchItem: element, row: row)
                cell.delegate = self
                self.requestNextPage(row: row, element: self.viewModel.totalSearchItem)
            }
            .disposed(by: disposeBag)

        output.noResultAction
            .drive { [weak self] bool in
                guard let self = self else { return }
                self.mainView.noResultView.isHidden = bool
            }
            .disposed(by: disposeBag)

        output.indicatorActin
            .drive { [weak self] bool in
                guard let self = self else { return }
                self.indicatorAction(bool: bool)
            }
            .disposed(by: disposeBag)

        output.failToastAction
            .emit { [weak self] errorMessage in
                guard let self = self else { return }
                self.mainView.makeToast(errorMessage)
            }
            .disposed(by: disposeBag)
    }

    private func requestUserList() {
        guard let query = mainView.searchBar.searchTextField.text else { return }
        requestUserListEvent.accept(query)
    }

    private func requestNextPage(row: Int, element: [UserItem]) {
        if row == element.count - 1 {
            guard let query = mainView.searchBar.searchTextField.text else { return }
            requestNextPageListEvent.accept(query)
        }
    }

    private func indicatorAction(bool: Bool) {
        if bool {
            mainView.indicatorView.isHidden = false
            mainView.indicatorView.indicatorView.startAnimating()
        } else {
            mainView.indicatorView.isHidden = true
            mainView.indicatorView.indicatorView.stopAnimating()
        }
    }
}

extension APIViewController: UISearchBarDelegate, UISearchTextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        requestUserList()
        textField.resignFirstResponder()
        return true
    }
}

extension APIViewController: SearchTableViewCellDelegate {
    func didTapFavoriteButton(row: Int) {
        pressFavoriteButtonEvent.accept(row)
    }
}