//
//  SearchViewModel.swift
//  GithubSearchApp
//
//  Created by 박근보 on 2022/04/23.
//

import Foundation
import RxSwift
import RxCocoa
import RealmSwift

final class SearchViewModel: ViewModelType {

    struct Input {
        // API Tab
        let requestUserListEvent: Signal<String>
        let requestNextPageListEvent: Signal<String>
        // Local Tab
        let searchFavoriteUserListEvent: Signal<String>
        // common
        let pressFavoriteButtonEvent: Signal<Int>
    }

    struct Output {
        // API Tab
        let didLoadUserList: Driver<[SearchItem]>
        // Local Tab
        let didLoadLocalUserList: Driver<[SearchItem]>
        // Common
        let didPressFavoriteButton: Signal<Int>
        let noResultAction: Driver<Bool>
        let failToastAction: Signal<String>
        let indicatorActin: Driver<Bool>
    }

    // API Tab
    private let didLoadUserList = BehaviorRelay<[SearchItem]>(value: [])
    // Local Tab
    private let didLoadLocalUserList = BehaviorRelay<[SearchItem]>(value: [])
    // Common
    private let didPressFavoriteButton = PublishRelay<Int>()
    private let noResultAction = BehaviorRelay<Bool>(value: false)
    private let failToastAction = PublishRelay<String>()
    private let indicatorAction = BehaviorRelay<Bool>(value: false)

    var disposeBag = DisposeBag()

    private var total = 0
    private var perPage = 30
    private var page = 1

    var totalSearchItem: [SearchItem] = []

    private var favoriteUserList: Results<FavoriteUserList>! {
        return RealmManager.shared.loadListData()
    }

    func transform(input: Input) -> Output {

        input.requestUserListEvent
            .emit { [weak self] query in
                guard let self = self else { return }
                self.indicatorAction.accept(true)
                self.requestSearchUser(query: query) { response in
                    switch response {
                    case .success(let data):
                        self.total = data.total
                        self.appendData(searchItem: data.searchItems)
                        self.checkIsFavoriteStatus()
                        self.didLoadUserList.accept(self.totalSearchItem)
                        self.noResultAction.accept(self.checkNoResult(searchItem: data.searchItems))
                        self.indicatorAction.accept(false)
                    case .failure(let error):
                        self.failToastAction.accept(error.errorDescription ?? "Error")
                        self.indicatorAction.accept(false)
                    }
                }
            }
            .disposed(by: disposeBag)

        input.requestNextPageListEvent
            .emit { [weak self] query in
                guard let self = self else { return }
                self.getNextPageMovieData(query: query) { response in
                    switch response {
                    case .success(let data):
                        self.appendData(searchItem: data.searchItems)
                        self.checkIsFavoriteStatus()
                        self.didLoadUserList.accept(self.totalSearchItem)
                    case .failure(let error):
                        self.failToastAction.accept(error.errorDescription ?? "Error")
                    }
                }
            }
            .disposed(by: disposeBag)

        input.pressFavoriteButtonEvent
            .emit { [weak self] row in
                guard let self = self else { return }
                self.totalSearchItem[row].isFavorite.toggle()
                self.checkDatabase(row: row)
                self.didLoadUserList.accept(self.totalSearchItem)
            }
            .disposed(by: disposeBag)

        return Output(
            didLoadUserList: didLoadUserList.asDriver(),
            didLoadLocalUserList: didLoadLocalUserList.asDriver(),
            didPressFavoriteButton: didPressFavoriteButton.asSignal(),
            noResultAction: noResultAction.asDriver(),
            failToastAction: failToastAction.asSignal(),
            indicatorActin: indicatorAction.asDriver()
        )
    }
}

extension SearchViewModel {

    private func requestSearchUser(query: String, completion: @escaping (Result<SearchData, SearchError>) -> Void) {
        totalSearchItem.removeAll()
        page = 1
        let parameter = [
            "q": "\(query)",
            "per_page": "\(perPage)",
            "page": "\(page)"
        ]
        APIManager.shared.requestSearchUser(parameter: parameter, completion: completion)
    }

    private func getNextPageMovieData(query: String, completion: @escaping (Result<SearchData, SearchError>) -> Void) {
        page += 1
        let parameter = [
            "q": "\(query)",
            "per_page": "\(perPage)",
            "page": "\(page)"
        ]
        if perPage * page <= total {
            APIManager.shared.requestSearchUser(parameter: parameter, completion: completion)
        } else {
            return
        }
    }

    private func checkIsFavoriteStatus() {
        for i in 0..<totalSearchItem.count {
            let filterValue = favoriteUserList.filter ("userId = '\(self.totalSearchItem[i].userID)'")
            if filterValue.count == 1 {
                totalSearchItem[i].isFavorite = true
            }
        }
    }

    private func checkDatabase(row: Int) {
        let filterValue = favoriteUserList.filter ("userId = '\(self.totalSearchItem[row].userID)'")
        if filterValue.count == 0 {
            addToDataBase(searchItem: totalSearchItem[row])
        } else {
            for i in 0..<favoriteUserList.count {
                if favoriteUserList[i].userId == totalSearchItem[row].userID {
                    removeFromDataBase(searchItem: favoriteUserList[i])
                    return
                }
            }
        }
    }

    private func checkNoResult(searchItem: [SearchItem]) -> Bool {
        if searchItem.count == 0 {
            return false
        } else {
            return true
        }
    }

    private func appendData(searchItem: [SearchItem]) {
        for i in searchItem {
            totalSearchItem.append(i)
        }
    }

    private func addToDataBase(searchItem: SearchItem) {
        let task = FavoriteUserList(userName: searchItem.userName,
                                    userId: searchItem.userID,
                                    userProfileImage: searchItem.userImage,
                                    isFavorite: true)
        RealmManager.shared.saveMovieListData(with: task)
    }

    private func removeFromDataBase(searchItem: FavoriteUserList) {
        RealmManager.shared.deleteObjectData(object: searchItem)
    }
}
