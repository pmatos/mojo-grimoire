struct ZzRes(Movable):
    var id: Int

struct ZzBad(Copyable):
    var r: ZzRes

struct Pair(Movable):
    var p: Pair

def main():
    print(1)
