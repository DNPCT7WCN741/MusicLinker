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

    private static let zh: [String: String] = [
        "app.title": "MusicLinker",
        "header.pasteLink": "粘贴音乐链接",
        "search.placeholder": "支持 Spotify / Apple Music / 网易云音乐…",
        "button.paste": "粘贴",
        "button.search": "搜索",
        "loading.text": "正在查找各平台链接…",
        "error.title": "无法获取链接",
        "history.title": "搜索记录",
        "history.empty": "暂无搜索记录",
        "history.clear": "清空记录",
        "platforms.title": "支持的平台",
        "result.generatePoster": "生成海报",
        "result.posterTip": "适合朋友圈大图分享，并可直接保存到相册",
        "result.preview": "生成海报",
        "result.playPreview": "试听15秒",
        "result.stopPreview": "停止试听",
        "result.share": "分享海报",
        "result.saveAlbum": "保存到相册",
        "result.platforms": "在以下平台收听",
        "result.songLink": "在 song.link 查看完整页面",
        "result.previewFailed": "试听失败",
        "result.previewError": "无法获取试听音源",
        "result.videoFailed": "视频生成失败",
        "result.videoError": "无法获取视频内容",
        "result.generateVideo": "生成视频",
        "result.shareVideo": "分享视频",
        "result.saveVideo": "保存视频",
        "result.ok": "知道了",
        "result.platforms.count": "个平台",
        "result.found": "已找到",
        "result.linksFound": "个平台链接",
        "result.needPhotoPermission": "需要相册访问权限才能保存海报\n请在设置中允许访问相册",
        "result.needPhotoPermissionSettings": "需要相册访问权限才能保存海报\n请在「设置 > MusicLinker」中允许访问相册",
        "result.posterGenerateFailed": "生成海报失败，请重试",
        "result.posterSaved": "已保存海报到相册",
        "result.saveFailed": "保存失败",
        "result.alert.title": "提示",
        "language.switch": "语言",
    ]

    private static let en: [String: String] = [
        "app.title": "MusicLinker",
        "header.pasteLink": "Paste Music Link",
        "search.placeholder": "Spotify / Apple Music / YouTube Music…",
        "button.paste": "Paste",
        "button.search": "Search",
        "loading.text": "Finding music links…",
        "error.title": "Failed to Get Links",
        "history.title": "Search History",
        "history.empty": "No search history",
        "history.clear": "Clear History",
        "platforms.title": "Supported Platforms",
        "result.generatePoster": "Generate Poster",
        "result.posterTip": "Perfect for social media sharing and direct album save",
        "result.preview": "Generate Poster",
        "result.playPreview": "Preview 15s",
        "result.stopPreview": "Stop Preview",
        "result.share": "Share Poster",
        "result.saveAlbum": "Save to Album",
        "result.platforms": "Listen on these platforms",
        "result.songLink": "View on song.link",
        "result.previewFailed": "Preview Failed",
        "result.previewError": "Unable to get preview",
        "result.videoFailed": "Video Generation Failed",
        "result.videoError": "Unable to generate video",
        "result.generateVideo": "Generate Video",
        "result.shareVideo": "Share Video",
        "result.saveVideo": "Save Video",
        "result.ok": "OK",
        "result.platforms.count": "platforms",
        "result.found": "Found",
        "result.linksFound": "platform links",
        "result.needPhotoPermission": "Photo library access required to save poster\nPlease allow access in Settings",
        "result.needPhotoPermissionSettings": "Photo library access required to save poster\nPlease allow access in Settings > MusicLinker",
        "result.posterGenerateFailed": "Failed to generate poster, please try again",
        "result.posterSaved": "Poster saved to album",
        "result.saveFailed": "Save failed",
        "result.alert.title": "Notice",
        "language.switch": "Language",
    ]

    private static let ja: [String: String] = [
        "app.title": "MusicLinker",
        "header.pasteLink": "音楽リンクを貼り付け",
        "search.placeholder": "Spotify / Apple Music / YouTube Music…",
        "button.paste": "貼り付け",
        "button.search": "検索",
        "loading.text": "音楽リンクを探索中…",
        "error.title": "リンク取得失敗",
        "history.title": "検索履歴",
        "history.empty": "検索履歴なし",
        "history.clear": "履歴を消去",
        "platforms.title": "対応プラットフォーム",
        "result.generatePoster": "ポスター生成",
        "result.posterTip": "ソーシャルメディア共有とアルバム保存に最適",
        "result.preview": "ポスター生成",
        "result.playPreview": "15秒プレビュー",
        "result.stopPreview": "プレビュー停止",
        "result.share": "ポスター共有",
        "result.saveAlbum": "アルバムに保存",
        "result.platforms": "以下のプラットフォームで聴く",
        "result.songLink": "song.linkで表示",
        "result.previewFailed": "プレビュー失敗",
        "result.previewError": "プレビュー取得失敗",
        "result.videoFailed": "ビデオ生成失敗",
        "result.videoError": "ビデオを生成できません",
        "result.generateVideo": "ビデオ生成",
        "result.shareVideo": "ビデオ共有",
        "result.saveVideo": "ビデオを保存",
        "result.ok": "了解",
        "result.platforms.count": "プラットフォーム",
        "result.found": "見つかりました",
        "result.linksFound": "プラットフォームリンク",
        "result.needPhotoPermission": "ポスターを保存するには写真ライブラリへのアクセスが必要です\n設定でアクセスを許可してください",
        "result.needPhotoPermissionSettings": "ポスターを保存するには写真ライブラリへのアクセスが必要です\n設定 > MusicLinker でアクセスを許可してください",
        "result.posterGenerateFailed": "ポスターの生成に失敗しました。もう一度お試しください",
        "result.posterSaved": "ポスターをアルバムに保存しました",
        "result.saveFailed": "保存に失敗しました",
        "result.alert.title": "お知らせ",
        "language.switch": "言語",
    ]

    private static let ru: [String: String] = [
        "app.title": "MusicLinker",
        "header.pasteLink": "Вставить музыкальную ссылку",
        "search.placeholder": "Spotify / Apple Music / YouTube Music…",
        "button.paste": "Вставить",
        "button.search": "Поиск",
        "loading.text": "Поиск музыкальных ссылок…",
        "error.title": "Не удалось получить ссылки",
        "history.title": "История поиска",
        "history.empty": "История поиска пуста",
        "history.clear": "Очистить историю",
        "platforms.title": "Поддерживаемые платформы",
        "result.generatePoster": "Создать постер",
        "result.posterTip": "Идеально для публикации в соцсетях и сохранения в альбом",
        "result.preview": "Создать постер",
        "result.playPreview": "Прослушать 15с",
        "result.stopPreview": "Остановить",
        "result.share": "Поделиться постером",
        "result.saveAlbum": "Сохранить в альбом",
        "result.platforms": "Слушать на платформах",
        "result.songLink": "Открыть на song.link",
        "result.previewFailed": "Ошибка прослушивания",
        "result.previewError": "Не удалось получить аудио",
        "result.videoFailed": "Ошибка создания видео",
        "result.videoError": "Не удалось создать видео",
        "result.generateVideo": "Создать видео",
        "result.shareVideo": "Поделиться видео",
        "result.saveVideo": "Сохранить видео",
        "result.ok": "Понятно",
        "result.platforms.count": "платформы",
        "result.found": "Найдено",
        "result.linksFound": "ссылок на платформы",
        "result.needPhotoPermission": "Требуется доступ к фотогалерее\nРазрешите доступ в настройках",
        "result.needPhotoPermissionSettings": "Требуется доступ к фотогалерее\nРазрешите доступ в Настройки > MusicLinker",
        "result.posterGenerateFailed": "Не удалось создать постер, попробуйте снова",
        "result.posterSaved": "Постер сохранён в альбом",
        "result.saveFailed": "Ошибка сохранения",
        "result.alert.title": "Уведомление",
        "language.switch": "Язык",
    ]

    func translate(_ key: String) -> String {
        switch currentLanguage {
        case .chinese:  return LanguageManager.zh[key] ?? key
        case .english:  return LanguageManager.en[key] ?? key
        case .japanese: return LanguageManager.ja[key] ?? key
        case .russian:  return LanguageManager.ru[key] ?? key
        }
    }
}
