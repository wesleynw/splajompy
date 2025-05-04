package db

type Facet struct {
	Type       string `json:"type"`
	UserId     int    `json:"userId"`
	IndexStart int    `json:"indexStart"`
	IndexEnd   int    `json:"indexEnd"`
}

type Facets []Facet
