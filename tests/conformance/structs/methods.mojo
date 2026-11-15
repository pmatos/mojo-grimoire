struct Account(Movable):
    var balance: Int

    def __init__(out self, balance: Int):
        self.balance = balance

    def deposit(mut self, amount: Int):
        self.balance += amount

    def get(self) -> Int:
        return self.balance


def main():
    var a = Account(10)
    a.deposit(5)
    a.deposit(7)
    print(a.get())
