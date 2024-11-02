# Fibonacci sequence in Python
def fibonacci(n):
    fib_sequence = [0, 1]
    for i in range(2, n):
        next_term = fib_sequence[i-1] + fib_sequence[i-2]
        fib_sequence.append(next_term)
    return fib_sequence[:n]

# Get the number of terms from the user
num_terms = int(input("Enter the number of terms: "))
print("Fibonacci sequence:", fibonacci(num_terms))
