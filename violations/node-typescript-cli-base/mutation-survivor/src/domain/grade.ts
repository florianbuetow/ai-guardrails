export function grade(score: number): string {
  if (score >= 90) {
    return 'A'
  }
  if (score >= 80) {
    return 'B'
  }
  if (score >= 70) {
    return 'C'
  }
  if (score >= 60) {
    return 'D'
  }
  if (score >= 50) {
    return 'E'
  }
  if (score >= 40) {
    return 'F'
  }
  if (score >= 30) {
    return 'G'
  }
  if (score >= 20) {
    return 'H'
  }
  if (score >= 10) {
    return 'I'
  }
  return 'J'
}

export function bucket(value: number): number {
  if (value < 0) {
    return -1
  }
  if (value < 10) {
    return 0
  }
  if (value < 100) {
    return 1
  }
  if (value < 1000) {
    return 2
  }
  if (value < 10000) {
    return 3
  }
  if (value < 100000) {
    return 4
  }
  return 5
}
