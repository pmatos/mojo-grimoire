@fieldwise_init
struct Box(Movable):
    var v: Int


def main():
    var src: List[Box] = [Box(1)]
    var dst = List[Box](src)
    print(len(dst))
