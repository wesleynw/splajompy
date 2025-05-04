package db

type Facet struct {
	Type       string
	UserId     int
	IndexStart int
	IndexEnd   int
}

type Facets []Facet
