// Package domain は codetrain-api / codetrain-pipeline が共有するドメイン型を定義する。
//
// REPOSITORIES.md §2.1 のとおり、api と pipeline は同じ DB を共有するため、
// スキーマに対応する型を1箇所（core）に置いて食い違いを防ぐ。
// 公開範囲は OPEN_ISSUES D-2 で検討中のため、まずは配信 API が必要とする最小限に絞る。
package domain

import "time"

// LLMGeneratedRawSourceID は「GitHub 収集をせず LLM のみで生成した問題」が指す
// raw_source の固定行 ID。PoC 段階では question.raw_source_id にこの値を入れる。
// マイグレーション 000001 が同じ ID で1行 INSERT している。
const LLMGeneratedRawSourceID = "00000000-0000-0000-0000-000000000001"

// QuestionType は問題タイプ。DB の question_type ENUM に対応する。
type QuestionType string

const (
	QuestionTypeCodeReading      QuestionType = "code_reading"
	QuestionTypeOutputPrediction QuestionType = "output_prediction"
	QuestionTypeBugFinding       QuestionType = "bug_finding"
	QuestionTypeFillInBlank      QuestionType = "fill_in_blank"
	QuestionTypeBestPractice     QuestionType = "best_practice"
)

// ValidQuestionType は s が question_type ENUM の5値のいずれかなら true。
func ValidQuestionType(s string) bool {
	switch QuestionType(s) {
	case QuestionTypeCodeReading, QuestionTypeOutputPrediction,
		QuestionTypeBugFinding, QuestionTypeFillInBlank, QuestionTypeBestPractice:
		return true
	}
	return false
}

// QuestionStatus は問題のライフサイクル。DB の question_status ENUM に対応する。
type QuestionStatus string

const (
	QuestionStatusDraft       QuestionStatus = "draft"
	QuestionStatusNeedsReview QuestionStatus = "needs_review"
	QuestionStatusPublished   QuestionStatus = "published"
	QuestionStatusRejected    QuestionStatus = "rejected"
)

// Skill はスキルツリーのトピック。ID は uuid。
type Skill struct {
	ID           string      `json:"id"`
	Slug         string      `json:"slug"`
	Name         string      `json:"name"`
	Description  string      `json:"description,omitempty"`
	DisplayOrder int         `json:"display_order"`
	Nodes        []SkillNode `json:"nodes,omitempty"`
}

// SkillNode はスキルツリーの単元。ID は uuid。
// 先修関係は skill_node_prerequisite（多対多）で表す。PrerequisiteNodeIDs が空なら
// ツリーの起点。
type SkillNode struct {
	ID                  string   `json:"id"`
	SkillID             string   `json:"skill_id"`
	PrerequisiteNodeIDs []string `json:"prerequisite_node_ids,omitempty"`
	Slug                string   `json:"slug"`
	Name                string   `json:"name"`
	Description         string   `json:"description,omitempty"`
	Difficulty          int      `json:"difficulty"`
	DisplayOrder        int      `json:"display_order"`
}

// Choice は選択肢1つ。DB では question.choices に JSONB の配列で入る。
type Choice struct {
	Key  string `json:"key"`
	Text string `json:"text"`
}

// Question は設問。CorrectKeys と Explanation は採点前のクライアントに返さないため、
// API のレスポンス型では別途絞り込む。
type Question struct {
	ID           string         `json:"id"`
	SkillNodeID  *string        `json:"skill_node_id,omitempty"`
	Type         QuestionType   `json:"type"`
	Status       QuestionStatus `json:"status"`
	Difficulty   int            `json:"difficulty"`
	Title        string         `json:"title"`
	Body         string         `json:"body"`
	Code         string         `json:"code,omitempty"`
	CodeLanguage string         `json:"code_language,omitempty"`
	Choices      []Choice       `json:"choices"`
	CorrectKeys  []string       `json:"correct_keys,omitempty"`
	Explanation  string         `json:"explanation,omitempty"`
	Tags         []string       `json:"tags,omitempty"`
	Attribution  *Attribution   `json:"attribution,omitempty"`
}

// Attribution は引用元の帰属表示。DESIGN.md §9 によりアプリ内での表示が必須のため、
// 問題と一緒に配信できるようにしておく。
type Attribution struct {
	RepoFullName string `json:"repo_full_name"`
	RepoURL      string `json:"repo_url"`
	CommitSHA    string `json:"commit_sha"`
	FilePath     string `json:"file_path"`
	LicenseSPDX  string `json:"license_spdx"`
	LicenseURL   string `json:"license_url,omitempty"`
	Author       string `json:"author,omitempty"`
}

// User は認証済みユーザー。ExternalID は認証基盤上の識別子
// （AUTH_MODE=cognito では Cognito の sub、dev では X-Dev-User の値）。
type User struct {
	ID          string    `json:"id"`
	ExternalID  string    `json:"external_id"`
	DisplayName string    `json:"display_name"`
	Email       string    `json:"email,omitempty"`
	CreatedAt   time.Time `json:"created_at"`
}

// Progress は XP・streak・現在のツリー位置。DB の user_progress は表示用キャッシュで、
// XP の真実の源は attempt、streak の真実の源は daily_task。配点や回復間隔などの
// パラメータは OPEN_ISSUES B-3 で未確定のため、値の保持のみ。
type Progress struct {
	XP                 int     `json:"xp"`
	Level              int     `json:"level"`
	StreakDays         int     `json:"streak_days"`
	LastStudiedOn      *string `json:"last_studied_on,omitempty"`
	Hearts             int     `json:"hearts"`
	CurrentSkillNodeID *string `json:"current_skill_node_id,omitempty"`
}

// TaskConfig はタスクスロット1件の条件。DB の user_task に対応する。
// Difficulty が nil のときは、サーバがユーザーの正答率から推奨レベルを解決する。
type TaskConfig struct {
	SlotNo       int          `json:"slot_no"`
	QuestionType QuestionType `json:"question_type"`
	Language     string       `json:"language"`
	Difficulty   *int         `json:"difficulty,omitempty"`
}

// DailyTask は「その日のホームに用意された1タスク」。DB の daily_task に対応する。
// CompletedAt が nil なら未消化。ActivityDate の全スロットが消化済みになった日が
// 連続タスク消化日数（streak）にカウントされる。
type DailyTask struct {
	ID           string       `json:"id"`
	ActivityDate string       `json:"activity_date"`
	SlotNo       int          `json:"slot_no"`
	QuestionType QuestionType `json:"question_type"`
	Language     string       `json:"language"`
	Difficulty   int          `json:"difficulty"`
	QuestionID   string       `json:"question_id"`
	CompletedAt  *time.Time   `json:"completed_at,omitempty"`
}

// ReviewDecision はレビュー判定。DB の review_decision ENUM に対応する。
// レビュー待ち中は review_queue.decision を NULL とするため、
// 未判定を表す型では *ReviewDecision を使う。
type ReviewDecision string

const (
	ReviewDecisionApproved  ReviewDecision = "approved"
	ReviewDecisionRejected  ReviewDecision = "rejected"
	ReviewDecisionNeedsEdit ReviewDecision = "needs_edit"
)

// Attempt は回答1回分の履歴。DB の attempt 行（DB_SCHEMA.md §5）に対応する追記専用ログ。
// DurationMS は所要時間（ミリ秒）で、計測できない場合は nil。
type Attempt struct {
	ID           string    `json:"id"`
	UserID       string    `json:"user_id"`
	QuestionID   string    `json:"question_id"`
	SelectedKeys []string  `json:"selected_keys"`
	IsCorrect    bool      `json:"is_correct"`
	DurationMS   *int      `json:"duration_ms,omitempty"`
	AnsweredAt   time.Time `json:"answered_at"`
}

// DailyTaskRef は AttemptResult.DailyTaskCompleted の入れ子。
// 今日の daily_task の未消化スロットに一致した回答のときだけ値が入る。
type DailyTaskRef struct {
	SlotNo       int    `json:"slot_no"`
	ActivityDate string `json:"activity_date"`
}

// AttemptResult は POST /v1/questions/{id}/attempts のレスポンス（API_DESIGN.md §3）。
// 採点結果と、同一トランザクションで更新した進捗を返す。
// DailyTaskCompleted は当日タスクに紐付かない回答では nil（JSON では null）。
type AttemptResult struct {
	AttemptID          string        `json:"attempt_id"`
	IsCorrect          bool          `json:"is_correct"`
	CorrectKeys        []string      `json:"correct_keys"`
	Explanation        string        `json:"explanation"`
	XPGained           int           `json:"xp_gained"`
	Progress           Progress      `json:"progress"`
	DailyTaskCompleted *DailyTaskRef `json:"daily_task_completed"`
}

// SRSDueItem は GET /v1/srs/due の1件（API_DESIGN.md §3。srs_state.due_on <= 今日）。
// レスポンスでは questions 配列に入り、due_on が古い順に並ぶ。
type SRSDueItem struct {
	ID           string       `json:"id"`
	Type         QuestionType `json:"type"`
	Difficulty   int          `json:"difficulty"`
	Title        string       `json:"title"`
	CodeLanguage string       `json:"code_language,omitempty"`
	Tags         []string     `json:"tags,omitempty"`
	DueOn        string       `json:"due_on"`
}

// TypeStat は GET /v1/me/stats の1件（DB の user_type_stat、または attempt 集約）。
// Language が "" のときは「言語を問わない」集計。Accuracy は corrects/attempts。
// LastDifficulty は直近に出題した難易度で、未出題なら nil。
type TypeStat struct {
	QuestionType   QuestionType `json:"question_type"`
	Language       string       `json:"language"`
	Attempts       int          `json:"attempts"`
	Corrects       int          `json:"corrects"`
	Accuracy       float64      `json:"accuracy"`
	LastDifficulty *int         `json:"last_difficulty"`
}

// TaskOption は available_task_option ビュー行 / GET /v1/task-slots/options の1件。
// published な問題バンクに実在する (種別, 言語, 難易度) の組み合わせのみ。
type TaskOption struct {
	QuestionType QuestionType `json:"question_type"`
	Language     string       `json:"language"`
	Difficulty   int          `json:"difficulty"`
}

// QuestionDetail は GET /v1/questions/{id} のレスポンス（API_DESIGN.md §3）。
// answered=false のとき CorrectKeys / Explanation は JSON null で返すため、
// ポインタにして nil = null を表現する。
type QuestionDetail struct {
	ID           string       `json:"id"`
	SkillNodeID  *string      `json:"skill_node_id,omitempty"`
	Type         QuestionType `json:"type"`
	Difficulty   int          `json:"difficulty"`
	Title        string       `json:"title"`
	Body         string       `json:"body"`
	Code         string       `json:"code,omitempty"`
	CodeLanguage string       `json:"code_language,omitempty"`
	Choices      []Choice     `json:"choices"`
	Tags         []string     `json:"tags,omitempty"`
	Attribution  *Attribution `json:"attribution,omitempty"`
	Answered     bool         `json:"answered"`
	CorrectKeys  *[]string    `json:"correct_keys"`
	Explanation  *string      `json:"explanation"`
}

// QuestionSummary は GET /v1/questions の軽量一覧行（API_DESIGN.md §3）。
// 詳細（body / choices / correct_keys / explanation）は含めない。
// Answered はログインユーザーがその問題に回答済みかどうか。
// CreatedAt はカーソルキー用で JSON には出さない。
type QuestionSummary struct {
	ID           string       `json:"id"`
	Type         QuestionType `json:"type"`
	Difficulty   int          `json:"difficulty"`
	Title        string       `json:"title"`
	CodeLanguage string       `json:"code_language,omitempty"`
	Tags         []string     `json:"tags,omitempty"`
	SkillNodeID  *string      `json:"skill_node_id,omitempty"`
	Answered     bool         `json:"answered"`
	CreatedAt    time.Time    `json:"-"`
}

// QuestionSearch は published 問題の検索条件。指定されたフィールドだけ絞る。
// Limit は返却件数（repository は Limit+1 件取得して次頁判定に使う）。
type QuestionSearch struct {
	SkillNodeID     string
	Type            QuestionType
	Language        string
	Difficulty      *int
	Tags            []string
	Query           string
	UnansweredOnly  bool
	CursorCreatedAt *time.Time
	CursorID        string
	Limit           int
}

// ReviewEntry は AdminQuestion.ReviewHistory の1行（review_queue 行）。
// Decision が nil の行が現在の未レビュー行（reviewer_id / notes も nil）。
type ReviewEntry struct {
	ID         string          `json:"id"`
	ReviewerID *string         `json:"reviewer_id"`
	Decision   *ReviewDecision `json:"decision"`
	Notes      *string         `json:"notes"`
	CreatedAt  time.Time       `json:"created_at"`
}

// AdminQuestion は GET /v1/admin/questions/{id} のレスポンス（API_DESIGN.md §3）。
// レビューに必要な全項目（正解・生成メタデータ・出典・レビュー履歴）を含む。
// 生成メタデータ（PromptVersion / ModelID / GenTokens / GeneratedAt）は手書き問題では nil。
type AdminQuestion struct {
	ID            string         `json:"id"`
	Status        QuestionStatus `json:"status"`
	Type          QuestionType   `json:"type"`
	Difficulty    int            `json:"difficulty"`
	Title         string         `json:"title"`
	Body          string         `json:"body"`
	Code          string         `json:"code,omitempty"`
	CodeLanguage  string         `json:"code_language,omitempty"`
	Choices       []Choice       `json:"choices"`
	CorrectKeys   []string       `json:"correct_keys"`
	Explanation   string         `json:"explanation,omitempty"`
	Tags          []string       `json:"tags,omitempty"`
	SkillNodeID   *string        `json:"skill_node_id,omitempty"`
	RawSourceID   string         `json:"raw_source_id"`
	PromptVersion string         `json:"prompt_version,omitempty"`
	ModelID       string         `json:"model_id,omitempty"`
	GenTokens     *int           `json:"gen_tokens,omitempty"`
	GeneratedAt   *time.Time     `json:"generated_at,omitempty"`
	ReviewHistory []ReviewEntry  `json:"review_history"`
}

// AdminQuestionSummary は GET /v1/admin/questions の一覧行（status を問わない横断検索）。
type AdminQuestionSummary struct {
	ID         string         `json:"id"`
	Status     QuestionStatus `json:"status"`
	Type       QuestionType   `json:"type"`
	Difficulty int            `json:"difficulty"`
	Title      string         `json:"title"`
	CreatedAt  time.Time      `json:"created_at"`
}

// ReviewQueueItem は GET /v1/admin/review-queue の一覧行
// （review_queue.decision IS NULL の未レビュー問題）。
type ReviewQueueItem struct {
	ReviewID   string       `json:"review_id"`
	QuestionID string       `json:"question_id"`
	Title      string       `json:"title"`
	Type       QuestionType `json:"type"`
	Difficulty int          `json:"difficulty"`
	QueuedAt   time.Time    `json:"queued_at"`
}

// ReviewResult は POST /v1/admin/questions/{id}/review のレスポンス（API_DESIGN.md §3）。
// review_queue に INSERT した行を返す。
type ReviewResult struct {
	ID         string         `json:"id"`
	QuestionID string         `json:"question_id"`
	ReviewerID string         `json:"reviewer_id"`
	Decision   ReviewDecision `json:"decision"`
	Notes      string         `json:"notes,omitempty"`
	ReviewedAt time.Time      `json:"reviewed_at"`
}
