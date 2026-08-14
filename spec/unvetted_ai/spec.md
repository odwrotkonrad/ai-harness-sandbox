# Spec

- k8s nodes are run in rootless mode

<!--[>] 🤖🤖 -->
Feature: Rootless cluster nodes

Scenario: node containers run as an unprivileged user, so breaking out of one gains no root
  Status: todo
  Given a running cluster
  When a node container's host-side owner is inspected
  Then it is an unprivileged user, not root
<!--[<] 🤖🤖 -->
