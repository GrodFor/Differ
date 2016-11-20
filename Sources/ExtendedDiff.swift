
public struct ExtendedDiff: DiffProtocol {
    
    public enum Element {
        case insert(at: Int)
        case delete(at: Int)
        case move(from: Int, to: Int)
    }
    
    /// Returns the position immediately after the given index.
    ///
    /// - Parameter i: A valid index of the collection. `i` must be less than
    ///   `endIndex`.
    /// - Returns: The index value immediately after `i`.
    public func index(after i: Int) -> Int {
        return i + 1
    }
    
    public let source: Diff
    /// An array which holds indices of diff elements in the source diff (i.e. diff without moves).
    public let reorderedIndex: [Int]
    public let elements: [ExtendedDiff.Element]
    public let moveIndices: Set<Int>
}

extension ExtendedDiff.Element {
    init(_ diffElement: Diff.Element) {
        switch diffElement {
        case let .delete(at):
            self = .delete(at: at)
        case let .insert(at):
            self = .insert(at: at)
        }
    }
}

public extension Collection where Iterator.Element : Equatable {

    public func extendedDiff(_ other: Self) -> ExtendedDiff {
        return extendedDiffFrom(diff(other), other: other)
    }
    
    fileprivate func extendedDiffFrom(_ diff: Diff, other: Self) -> ExtendedDiff {
        
        
        var elements: [ExtendedDiff.Element] = []
        var dirtyDiffElements: Set<Diff.Index> = []
        var sourceIndex = [Int]()
        var moveIndices = Set<Int>()
        
        
        // Complexity O(d^2) where d is the length of the diff
        
        /*
         * 1. Iterate all objects
         * 2. For every iteration find the next matching element
         a) if it's not found insert the element as is to the output array
         b) if it's found calculate move as in 3
         * 3. Calculating the move.
         We call the first element a *candidate* and the second element a *match*
         1. The position of the candidate never changes
         2. The position of the match is equal to its initial position + m where m is equal to -d + i where d = deletions between candidate and match and i = insertions between candidate and match
         * 4. Remove the candidate and match and insert the move in the place of the candidate
         *
         */
        
        for candidateIndex in diff.indices {
            if !dirtyDiffElements.contains(candidateIndex) {
                let candidate = diff[candidateIndex]
                let match = firstMatch(diff, dirtyIndices: dirtyDiffElements, candidate: candidate, candidateIndex: candidateIndex, other: other)
                if let match = match {
                    sourceIndex.append(candidateIndex) // Index of the deletion
                    sourceIndex.append(match.1) // Index of the insertion
                    moveIndices.insert(candidateIndex)
                    dirtyDiffElements.insert(match.1)
                    elements.append(match.0)
                } else {
                    sourceIndex.append(candidateIndex)
                    elements.append(ExtendedDiff.Element(candidate))
                }
            }
        }
        
        let reorderedIndices = zip(sourceIndex, sourceIndex.indices)
            .sorted { $0.0 < $1.0 }
            .map { $0.1 }
        
        return ExtendedDiff(
            source: diff,
            reorderedIndex: reorderedIndices,
            elements: elements,
            moveIndices: moveIndices
        )
    }
    
    func firstMatch(
        _ diff: Diff,
        dirtyIndices: Set<Diff.Index>,
        candidate: Diff.Element,
        candidateIndex: Diff.Index,
        other: Self) -> (ExtendedDiff.Element, Diff.Index)? {
        for matchIndex in (candidateIndex + 1)..<diff.endIndex {
            
            if !dirtyIndices.contains(matchIndex) {
                let match = diff[matchIndex]
                if let move = createMatCH(candidate, match: match, other: other) {
                    return (move, matchIndex)
                }
            }
        }
        return nil
    }
    
    func createMatCH(_ candidate: Diff.Element, match: Diff.Element, other: Self) -> ExtendedDiff.Element? {
        switch (candidate, match) {
        case (.delete, .insert):
            if itemOnStartIndex(advancedBy: candidate.at()) == other.itemOnStartIndex(advancedBy: match.at()) {
                return .move(from: candidate.at(), to: match.at())
            }
        case (.insert, .delete):
            if itemOnStartIndex(advancedBy: match.at()) == other.itemOnStartIndex(advancedBy: candidate.at()) {
                return .move(from: match.at(), to: candidate.at())
            }
        default: return nil
        }
        return nil
    }
    
    func itemOnStartIndex(advancedBy n: Int) -> Iterator.Element {
        return self[self.index(startIndex, offsetBy: IndexDistance(n.toIntMax()))]
    }
}

extension ExtendedDiff.Element: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case let .delete(at):
            return "D(\(at))"
        case let .insert(at):
            return "I(\(at))"
        case let .move(from, to):
            return "M(\(from)\(to))"
        }
    }
}
