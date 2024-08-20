package web

import (
	"errors"
	"io"
	"net/http"
	"strconv"
	gamemanager "terralance/pkg/game_manager"
	"terralance/pkg/utils"

	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
)

var _ = gamemanager.GM
var _ = errors.ErrUnsupported

func SetupServer(e *echo.Echo) {
	e.Use(middleware.Logger())

	e.GET("/", func(c echo.Context) error {
		return c.String(http.StatusOK, "Hello world!")
	})

	e.GET("/game/flush", flush)
	e.GET("/game/:id", game)
}

func game(c echo.Context) error {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		return err
	}

	game, err := gamemanager.GetGame(id)
	if err != nil {
		return err
	}

	n, err := io.WriteString(game.Stdin, "W\n")
	if err != nil {
		return err
	}
	utils.Assert(n == 2, "(stdin) i think this is right")

	buf := make([]byte, 8192)
	n, err = io.ReadAtLeast(game.Stdout, buf, 1)
	if err != nil {
		return err
	}
	str := buf[0:n]

	return c.String(http.StatusOK, string(str))
}

func flush(c echo.Context) error {
	gamemanager.Flush()

	return c.String(http.StatusOK, "Flushed away!")
}
