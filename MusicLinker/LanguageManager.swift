import SwiftUI
import Combine

enum AppLanguage: String, CaseIterable {
    case chinese = "zh"
    case english = "en"
    case japanese = "ja"
    case russian = "ru"
    
    var displayName: String {
        switch self {
        case .chinese: return "中文"
        case .english: return "English"
        case .japanese: return "日本語"
        case .russian: return "Русский"
        }
    }
}

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @Published var currentLanguage: AppLanguage = .chinese {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "appLanguage")
        }
    }
    
    private init() {
        let savedLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "zh"
        self.currentLanguage = AppLanguage(rawValue: savedLanguage) ?? .chinese
    }
    
    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
    }
    
    func translate(_ key: String) -> String {
        let translations: [String: [AppLanguage: String]] = [
            // Header & Navigation
            "app.title": [
                .chinese: "MusicLinker",
                .english: "MusicLinker",
                .japanese: "MusicLinker",
                .russian: "MusicLinker"
            ],
            "header.pasteLink": [
                .chinese: "粘贴音乐链接",
                .english: "Paste Music Link",
                .japanese: "音楽リンクを貼り付け",
                .russian: "Вставить музыкальную ссылку"
            ],
            "button.paste": [
                .chinese: "粘贴",
                .english: "Paste",
                .japanese: "貼り付け",
                .russian: "Вставить"
            ],
            "button.search": [
                .chinese: "搜索",
                .english: "Search",
                .japanese: "検索",
                .russian: "Поиск"
            ],
            "loading.text": [
                .chinese: "正在查找各平台链接…",
                .english: "Finding music links…",
                .japanese: "音楽リンクを探索中…",
                .russian: "Поиск музыкальных ссылок…"
            ],
            "error.title": [
                .chinese: "无法获取链接",
                .english: "Failed to Get Links",
                .japanese: "リンク取得失敗",
                .russian: "Не удалось получить ссылки"
            ],
            "history.title": [
                .chinese: "搜索记录",
                .english: "Search History",
                .japanese: "検索履歴",
                .russian: "История поиска"
            ],
            "history.empty": [
                .chinese: "暂无搜索记录",
                .english: "No search history",
                .japanese: "検索履歴なし",
                .russian: "История поиска пуста"
            ],
            "history.clear": [
                .chinese: "清空记录",
                .english: "Clear History",
                .japanese: "履歴を消去",
                .russian: "Очистить историю"
            ],
            "platforms.title": [
                .chinese: "支持的平台",
                .english: "Supported Platforms",
                .japanese: "対応プラットフォーム",
                .russian: "Поддерживаемые платформы"
            ],
            // Result View
            "result.generatePoster": [
                .chinese: "生成海报",
                .english: "Generate Poster",
                .japanese: "ポスター生成",
                .russian: "Создать постер"
            ],
            "result.posterTip": [
                .chinese: "适合朋友圈大图分享，并可直接保存到相册",
                .english: "Perfect for social media sharing and direct album save",
                .japanese: "ソーシャルメディア共有とアルバム保存に最適",
                .russian: "Идеально для публикации в соцсетях и сохранения в альбом"
            ],
            "result.preview": [
                .chinese: "生成海报",
                .english: "Generate Poster",
                .japanese: "ポスター生成",
                .russian: "Создать постер"
            ],
            "result.playPreview": [
                .chinese: "试听15秒",
                .english: "Preview 15s",
                .japanese: "15秒プレビュー",
                .russian: "Прослушать 15с"
            ],
            "result.stopPreview": [
                .chinese: "停止试听",
                .english: "Stop Preview",
                .japanese: "プレビュー停止",
                .russian: "Остановить"
            ],
            "result.share": [
                .chinese: "分享海报",
                .english: "Share Poster",
                .japanese: "ポスター共有",
                .russian: "Поделиться постером"
            ],
            "result.saveAlbum": [
                .chinese: "保存到相册",
                .english: "Save to Album",
                .japanese: "アルバムに保存",
                .russian: "Сохранить в альбом"
            ],
            "result.platforms": [
                .chinese: "在以下平台收听",
                .english: "Listen on these platforms",
                .japanese: "以下のプラットフォームで聴く",
                .russian: "Слушать на платформах"
            ],
            "result.songLink": [
                .chinese: "在 song.link 查看完整页面",
                .english: "View on song.link",
                .japanese: "song.linkで表示",
                .russian: "Открыть на song.link"
            ],
            "result.previewFailed": [
                .chinese: "试听失败",
                .english: "Preview Failed",
                .japanese: "プレビュー失敗",
                .russian: "Ошибка прослушивания"
            ],
            "result.previewError": [
                .chinese: "无法获取试听音源",
                .english: "Unable to get preview",
                .japanese: "プレビュー取得失敗",
                .russian: "Не удалось получить аудио"
            ],
            "result.videoFailed": [
                .chinese: "视频生成失败",
                .english: "Video Generation Failed",
                .japanese: "ビデオ生成失敗",
                .russian: "Ошибка создания видео"
            ],
            "result.videoError": [
                .chinese: "无法获取视频内容",
                .english: "Unable to generate video",
                .japanese: "ビデオを生成できません",
                .russian: "Не удалось создать видео"
            ],
            "result.generateVideo": [
                .chinese: "生成视频",
                .english: "Generate Video",
                .japanese: "ビデオ生成",
                .russian: "Создать видео"
            ],
            "result.shareVideo": [
                .chinese: "分享视频",
                .english: "Share Video",
                .japanese: "ビデオ共有",
                .russian: "Поделиться видео"
            ],
            "result.saveVideo": [
                .chinese: "保存视频",
                .english: "Save Video",
                .japanese: "ビデオを保存",
                .russian: "Сохранить видео"
            ],
            "result.ok": [
                .chinese: "知道了",
                .english: "OK",
                .japanese: "了解",
                .russian: "Понятно"
            ],
            "result.platforms.count": [
                .chinese: "个平台",
                .english: "platforms",
                .japanese: "プラットフォーム",
                .russian: "платформы"
            ],
            "result.found": [
                .chinese: "已找到",
                .english: "Found",
                .japanese: "見つかりました",
                .russian: "Найдено"
            ],
            "result.linksFound": [
                .chinese: "个平台链接",
                .english: "platform links",
                .japanese: "プラットフォームリンク",
                .russian: "ссылок на платформы"
            ],
            "result.needPhotoPermission": [
                .chinese: "需要相册访问权限才能保存海报\n请在设置中允许访问相册",
                .english: "Photo library access required to save poster\nPlease allow access in Settings",
                .japanese: "ポスターを保存するには写真ライブラリへのアクセスが必要です\n設定でアクセスを許可してください",
                .russian: "Требуется доступ к фотогалерее\nРазрешите доступ в настройках"
            ],
            "result.needPhotoPermissionSettings": [
                .chinese: "需要相册访问权限才能保存海报\n请在「设置 > MusicLinker」中允许访问相册",
                .english: "Photo library access required to save poster\nPlease allow access in Settings > MusicLinker",
                .japanese: "ポスターを保存するには写真ライブラリへのアクセスが必要です\n設定 > MusicLinker でアクセスを許可してください",
                .russian: "Требуется доступ к фотогалерее\nРазрешите доступ в Настройки > MusicLinker"
            ],
            "result.posterGenerateFailed": [
                .chinese: "生成海报失败，请重试",
                .english: "Failed to generate poster, please try again",
                .japanese: "ポスターの生成に失敗しました。もう一度お試しください",
                .russian: "Не удалось создать постер, попробуйте снова"
            ],
            "result.posterSaved": [
                .chinese: "已保存海报到相册",
                .english: "Poster saved to album",
                .japanese: "ポスターをアルバムに保存しました",
                .russian: "Постер сохранён в альбом"
            ],
            "result.saveFailed": [
                .chinese: "保存失败",
                .english: "Save failed",
                .japanese: "保存に失敗しました",
                .russian: "Ошибка сохранения"
            ],
            "result.alert.title": [
                .chinese: "提示",
                .english: "Notice",
                .japanese: "お知らせ",
                .russian: "Уведомление"
            ],
            "language.switch": [
                .chinese: "语言",
                .english: "Language",
                .japanese: "言語",
                .russian: "Язык"
            ]
        ]
        
        return translations[key]?[currentLanguage] ?? key
    }
}
