package models

type Chart struct {
	Name string
	ApiVersion string
	Description string
	Type string
	Version string
	AppVersion string
	Dependencies []Dependency
}

type Dependency struct {
	Name string
	Version string
	Repository string

	
}