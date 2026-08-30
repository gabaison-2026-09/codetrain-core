// Package domain は codetrain-api / codetrain-pipeline が共有するドメイン型を定義する。
//
// REPOSITORIES.md §2.1 のとおり、api と pipeline は同じ DB を共有するため、
// スキーマに対応する型を1箇所（core）に置いて食い違いを防ぐ。
// 公開範囲は OPEN_ISSUES D-2 で検討中のため、まずは配信 API が必要とする最小限に絞る。
package domain

import "time"

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

// Skill はスキルツリーのトピック。
type Skill struct {
	ID           int64       `json:"id"`
	Slug         string      `json:"slug"`
	Name         string      `json:"name"`
	Description  string      `json:"description,omitempty"`
	DisplayOrder int         `json:"display_order"`
	Nodes        []SkillNode `json:"nodes,omitempty"`
}

// SkillNode はスキルツリーの単元。ParentID が nil ならツリーの起点。
type SkillNode struct {
	ID           int64  `json:"id"`
	SkillID      int64  `json:"skill_id"`
	ParentID     *int64 `json:"parent_id,omitempty"`
	Slug         string `json:"slug"`
	Name         string `json:"name"`
	Description  string `json:"description,omitempty"`
	Difficulty   int    `json:"difficulty"`
	DisplayOrder int    `json:"display_order"`
}

// Choice は選択肢1つ。DB では question.choices に JSONB の配列で入る。
type Choice struct {
	Key  string `json:"key"`
	Text string `json:"text"`
}

// Question は設問。CorrectKeys と Explanation は採点前のクライアントに返さないため、
// API のレスポンス型では別途絞り込む。
type Question struct {
	ID           int64          `json:"id"`
	SkillNodeID  *int64         `json:"skill_node_id,omitempty"`
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
	ID          int64     `json:"id"`
	ExternalID  string    `json:"external_id"`
	DisplayName string    `json:"display_name"`
	Email       string    `json:"email,omitempty"`
	CreatedAt   time.Time `json:"created_at"`
}

// Progress は XP・streak・現在のツリー位置。
// 配点や回復間隔などのパラメータは OPEN_ISSUES B-3 で未確定のため、値の保持のみ。
type Progress struct {
	XP                 int     `json:"xp"`
	StreakDays         int     `json:"streak_days"`
	LastStudiedOn      *string `json:"last_studied_on,omitempty"`
	Hearts             int     `json:"hearts"`
	CurrentSkillNodeID *int64  `json:"current_skill_node_id,omitempty"`
}
