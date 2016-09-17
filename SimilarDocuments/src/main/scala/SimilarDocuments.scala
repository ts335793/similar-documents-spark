import Function.tupled
import org.apache.spark.SparkContext
import org.apache.spark.SparkConf

object SimilarDocuments {

  def sieve(s: Stream[Int]): Stream[Int] = {
    s.head #:: sieve(s.tail.filter(_ % s.head != 0))
  }

  val primes = sieve(Stream.from(2))

  def hashFunction(smallPrime: Int, bigPrime: Int)(i: Int): Int = (smallPrime * i) % bigPrime

  def jaccardSimilarity(v1: Vector[Boolean], v2: Vector[Boolean]): Double = {
    val zipped = v1 zip v2
    val a = zipped count tupled ((x, y) => x && y)
    val b = zipped count tupled ((x, y) => x || y)
    a.toDouble / b.toDouble
  }

  def main(args: Array[String]) {
    val path = args(0)
    val shingleSize = args(1) toInt
    val signatureSize = args(2) toInt
    val numberOfBounds = args(3) toInt

    val sparkConfiguration = new SparkConf
    sparkConfiguration setAppName "SimilarDocuments"

    val sparkContext = new SparkContext(sparkConfiguration)

    val filesToContents = sparkContext wholeTextFiles path

    val filesToShingles = filesToContents map tupled ((file, content) => {
      var shingles = content map (_ toString)
      for (i <- 1 until shingleSize)
        shingles = shingles zip (content drop i) map tupled (_ + _)
      (file, shingles toSet)
    }) cache

    val allShingles = filesToShingles map (_._2) reduce (_ union _) toVector

    val filesToVectors = filesToShingles map tupled ((file, shingles) => {
      val vector = allShingles map (shingles contains)
      (file, vector)
    }) cache

    val filesToVectorsMap = (filesToVectors collect) toMap

    val hashFunctionParameters = primes dropWhile (_ <= allShingles.length) take 2 * signatureSize toVector

    val filesToSignatures = filesToVectors map tupled ((file, vector) => {
      val signature =
        ((for(i <- 0 until signatureSize;
            permutation = hashFunction(hashFunctionParameters(2 * i), hashFunctionParameters(2 * i + 1))_)
          yield (vector indices) filter vector map permutation min) toVector)
      (file, signature)
    })

    val bandsToFiles = filesToSignatures flatMap tupled ((file, vector) => {
      val bandsToRows = ((vector zipWithIndex) groupBy (_._2 / numberOfBounds)) mapValues (x => x map (_._1))
      val bandsToFile = bandsToRows map (x => (x, file))
      bandsToFile
    })

    val buckets = (bandsToFiles groupByKey) map (_._2)

    val pairsInBuckets = buckets map (bucket => (for (file1 <- bucket; file2 <- bucket; if(file1 < file2)) yield (file1, file2)) toSet)

    val candidatePairs = pairsInBuckets reduce (_ union _)

    println("Candidate pairs:")
    for ((file1, file2) <- candidatePairs) {
      val Some(vector1) = filesToVectorsMap get file1
      val Some(vector2) = filesToVectorsMap get file2
      val similarity = jaccardSimilarity(vector1, vector2)
      println(similarity.toString ++ "\t" ++ file1 ++ " " ++ file2)
    }
  }
}
