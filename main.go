package main

import (
	"terralance/pkg/web"

	"github.com/labstack/echo/v4"
)

func main() {
	e := echo.New()

	web.SetupServer(e)

	e.Logger.Fatal(e.Start(":3000"))
}
