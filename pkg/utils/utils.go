package utils

func Assert(ok bool, msg string) {
	if !ok {
		panic(msg)
	}
}
