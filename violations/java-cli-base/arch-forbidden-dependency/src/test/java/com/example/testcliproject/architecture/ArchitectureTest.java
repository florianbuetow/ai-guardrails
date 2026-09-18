package com.example.testcliproject.architecture;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;

import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchRule;

@AnalyzeClasses(
    packages = "com.example.testcliproject",
    importOptions = ImportOption.DoNotIncludeTests.class)
class ArchitectureTest {

  @ArchTest
  static final ArchRule no_classes_should_depend_on_test_classes =
      noClasses()
          .that()
          .resideOutsideOfPackage("..test..")
          .should()
          .dependOnClassesThat()
          .resideInAPackage("..test..");

  @ArchTest
  static final ArchRule no_direct_system_access =
      noClasses()
          .should()
          .accessClassesThat()
          .haveFullyQualifiedName("java.lang.System");
}
