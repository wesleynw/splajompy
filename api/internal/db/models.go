package db

type Facet struct {
	Type       string `json:"type"`
	UserId     int    `json:"userId"`
	IndexStart int    `json:"indexStart"`
	IndexEnd   int    `json:"indexEnd"`
}

type Facets []Facet

type Attributes struct {
	Poll Poll `json:"poll"`
}

type Poll struct {
	Title   string   `json:"title"`
	Options []string `json:"options"`
}

type UserDisplayProperties struct {
	FontChoiceId *int `json:"fontChoiceId"`
}
