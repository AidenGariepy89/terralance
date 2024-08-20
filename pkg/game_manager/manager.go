package gamemanager

import (
	"fmt"
	"io"
	"log"
	"os/exec"
	"terralance/pkg/utils"
)

type Game struct {
	Id     int64
	Cmd    *exec.Cmd
	Stdin  io.WriteCloser
	Stdout io.ReadCloser
}

func (g *Game) Quit() error {
	_, err := io.WriteString(g.Stdin, "Q\n")
	if err != nil {
		return err
	}

	g.Stdin.Close()
	g.Stdout.Close()

	err = g.Cmd.Wait()
	if err != nil {
		return err
	}

	return nil
}

type GameManager struct {
	Games    [4]*Game
	NextGame int
}

var GM GameManager = GameManager{
	Games:    [4]*Game{nil, nil, nil, nil},
	NextGame: 0,
}

func GetGame(id int64) (*Game, error) {
	for i := range GM.Games {
		game := GM.Games[i]
		if game == nil {
			continue
		}
		if game.Id == id {
			return game, nil
		}
	}

	utils.Assert(GM.NextGame < len(GM.Games) && GM.NextGame >= 0, "GM.NextGame must be in range!")

	cmd := exec.Command("zig", "build", "run", "--", "hello", "world", "from", fmt.Sprint(id))
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return nil, err
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return nil, err
	}
	err = cmd.Start()
	if err != nil {
		return nil, err
	}

	gameIdx := GM.NextGame
	if GM.Games[gameIdx] != nil {
		err = GM.Games[gameIdx].Quit()
		if err != nil {
			return nil, err
		}
	}
	GM.Games[gameIdx] = &Game{
		Id:     id,
		Cmd:    cmd,
		Stdin:  stdin,
		Stdout: stdout,
	}

	GM.NextGame += 1
	if GM.NextGame >= len(GM.Games) {
		GM.NextGame = 0
	}

	return GM.Games[gameIdx], nil
}

func Flush() {
	for i, game := range GM.Games {
		if game == nil {
			continue
		}
		if game.Cmd.Process == nil {
			GM.Games[i] = nil
			continue
		}

		err := game.Quit()
		if err != nil {
			log.Fatal(err.Error())
		}
	}
}
