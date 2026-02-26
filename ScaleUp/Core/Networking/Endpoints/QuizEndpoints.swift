import Foundation

// MARK: - Quiz Endpoints

enum QuizEndpoints {

    // MARK: - Request Bodies

    struct RequestQuizBody: Encodable {
        let topic: String
        let contentIds: [String]?
    }

    struct AnswerBody: Encodable {
        let questionIndex: Int
        let selectedAnswer: String
        let timeTaken: Double
    }

    // MARK: - Endpoints

    static func list() -> Endpoint {
        .get("/quizzes")
    }

    static func history() -> Endpoint {
        .get("/quizzes/history")
    }

    static func request(topic: String, contentIds: [String]? = nil) -> Endpoint {
        .post("/quizzes/request", body: RequestQuizBody(topic: topic, contentIds: contentIds))
    }

    static func getQuiz(id: String) -> Endpoint {
        .get("/quizzes/\(id)")
    }

    static func start(id: String) -> Endpoint {
        .post("/quizzes/\(id)/start")
    }

    static func answer(id: String, questionIndex: Int, selectedAnswer: String, timeTaken: Double) -> Endpoint {
        .put(
            "/quizzes/\(id)/answer",
            body: AnswerBody(questionIndex: questionIndex, selectedAnswer: selectedAnswer, timeTaken: timeTaken)
        )
    }

    static func complete(id: String) -> Endpoint {
        .post("/quizzes/\(id)/complete")
    }

    static func results(id: String) -> Endpoint {
        .get("/quizzes/\(id)/results")
    }

    static func triggerStatus(triggerId: String) -> Endpoint {
        .get("/quizzes/trigger/\(triggerId)")
    }
}
