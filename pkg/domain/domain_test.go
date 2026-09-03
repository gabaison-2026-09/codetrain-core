package domain

import (
	"encoding/json"
	"testing"
)

func TestTaskConfigMarshalJSON(t *testing.T) {
	t.Run("difficulty nil is encoded as null", func(t *testing.T) {
		got, err := json.Marshal(TaskConfig{
			SlotNo:       3,
			QuestionType: QuestionTypeCodeReading,
			Language:     "typescript",
			Difficulty:   nil,
		})
		if err != nil {
			t.Fatalf("json.Marshal: %v", err)
		}

		want := `{"slot_no":3,"question_type":"code_reading","language":"typescript","difficulty":null}`
		if string(got) != want {
			t.Errorf("JSON = %s, want %s", got, want)
		}
	})

	t.Run("difficulty value is encoded as a number", func(t *testing.T) {
		difficulty := 4
		got, err := json.Marshal(TaskConfig{
			SlotNo:       1,
			QuestionType: QuestionTypeBugFinding,
			Language:     "go",
			Difficulty:   &difficulty,
		})
		if err != nil {
			t.Fatalf("json.Marshal: %v", err)
		}

		want := `{"slot_no":1,"question_type":"bug_finding","language":"go","difficulty":4}`
		if string(got) != want {
			t.Errorf("JSON = %s, want %s", got, want)
		}
	})
}
