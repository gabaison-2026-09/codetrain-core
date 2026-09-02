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
