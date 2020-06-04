Class {
	#name : #VMLiveTypingTrampolineTest,
	#superclass : #VMSimpleStackBasedCogitAbstractTest,
	#category : #VMMakerTests
}

{ #category : #running }
VMLiveTypingTrampolineTest >> cogitClass [
	^ StackToRegisterMappingCogit 
]

{ #category : #running }
VMLiveTypingTrampolineTest >> compile: aBlock bytecodes: aNumberOfBytecodes headerSize: headerSize [
	cogit methodOrBlockNumTemps: 0.
	cogit methodOrBlockNumArgs: 0.
	cogit initSimStackForFramefulMethod: 0.
	cogit useTwoPaths: false.
	^ super compile: aBlock bytecodes: aNumberOfBytecodes headerSize: headerSize.
	
]

{ #category : #tests }
VMLiveTypingTrampolineTest >> doPopIntoReceiverVariableBytecodeStoresVariableAt: instanceVariableToWrite [
	|asigningMethod|

	"Create an object with at least `instanceVariableToWrite` instance variables.
	In memory, instance variables are 0-indexed so substract 1"
	obj := self newObjectWithSlots: instanceVariableToWrite.
	
	"The receiver should be in a receiver register based on Cog's calling convention"
	machineSimulator receiverRegisterValue: obj.

	"The object is filled with nils.
	Push false into the stack and execute the store and pop bytecode."	
	self pushAddress: memory falseObject.
	
	"Set an address as store check trampoline.
	The bytecode below will jump to it if it is a old -> young store"
	cogit objectRepresentation ceStoreCheckTrampoline: memory nilObject.
	
	"The first byte of the push receiver instance variable bytecode family is used to identify which variable (0-based again)"
	cogit byte0: instanceVariableToWrite - 1.		
	asigningMethod := self compile: [ 
		cogit genPushConstantOneBytecode.
		cogit genStoreAndPopReceiverVariableBytecode ].	
	self halt.
	self openMachineDebuggerAt: asigningMethod.
	self runGeneratedCode.
]

{ #category : #running }
VMLiveTypingTrampolineTest >> setUp [
	super setUp.
	
	cogit generateLiveTypingTrampolines.
	

]

{ #category : #tests }
VMLiveTypingTrampolineTest >> testGenerateTrampolineAssignValidAddresses [

	self assert: cogit keepInstanceVariableTypeTrampoline notNil.
]

{ #category : #tests }
VMLiveTypingTrampolineTest >> testInstanceVariableStoreJumpsToLiveTypingTrampoline [
	| cogMethod otherBlock |
	otherBlock := self compile: [ cogit Nop ].
	self doPopIntoReceiverVariableBytecodeStoresVariableAt: 1.
	
	"Let's set any value in the ClassRegister"
	machineSimulator classRegisterValue: 16rFF.
	
	self runFrom: cogMethod address + cogit entryOffset until: cogit ceMethodAbortTrampoline.

	self assert: machineSimulator instructionPointerValue equals: cogit ceMethodAbortTrampoline 
]
